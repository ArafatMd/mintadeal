package com.mintadeal.ops;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.customer.VendorFollowRepository;
import com.mintadeal.ops.StatsDtos.AdminOverview;
import com.mintadeal.ops.StatsDtos.Attention;
import com.mintadeal.ops.StatsDtos.Day;
import com.mintadeal.ops.StatsDtos.TopItem;
import com.mintadeal.ops.StatsDtos.VendorStats;
import com.mintadeal.review.ReviewDtos.RatingSummary;
import com.mintadeal.review.ReviewService;

/** Numbers for the admin home and the shop's performance screen, straight from the database. */
@Service
public class StatsService {

    static final ZoneId INDIA = ZoneId.of("Asia/Kolkata");

    /** Orders that count: paid or pay-later, and not cancelled. */
    private static final String REAL_ORDER = "status not in ('PENDING_PAYMENT', 'CANCELLED')";

    private final JdbcTemplate jdbc;
    private final ReviewService reviews;
    private final VendorFollowRepository follows;
    private final Clock clock;

    public StatsService(JdbcTemplate jdbc, ReviewService reviews, VendorFollowRepository follows, Clock clock) {
        this.jdbc = jdbc;
        this.reviews = reviews;
        this.follows = follows;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AdminOverview overview() {
        LocalDate today = LocalDate.now(clock.withZone(INDIA));
        Timestamp startToday = start(today);
        Instant now = clock.instant();
        long ordersToday = count("select count(*) from shop_order where created_at >= ? and " + REAL_ORDER, startToday);
        long completedToday = count("select count(*) from shop_order where completed_at >= ?", startToday);
        long cancelledToday = count("select count(*) from shop_order where cancelled_at >= ?", startToday);
        long valueToday = count("select coalesce(sum(total_minor), 0) from shop_order where created_at >= ? and "
                + REAL_ORDER, startToday);
        List<Day> week = days("select created_at, total_minor from shop_order where created_at >= ? and "
                + REAL_ORDER, null, today, 7);
        Attention attention = new Attention(
                count("select count(*) from support_ticket where status = 'OPEN'"),
                count("select count(*) from shop_order where status = 'PLACED'"),
                count("select count(*) from delivery_job where status = 'REQUESTED'"),
                count("select count(*) from notification where status = 'FAILED' and created_at >= ?",
                        Timestamp.from(now.minusSeconds(86_400))),
                count("select count(*) from refund where status = 'FAILED'"),
                count("select count(*) from payout where status = 'FAILED'"),
                count("select count(*) from vendor where status = 'PENDING'"));
        return new AdminOverview(ordersToday, completedToday, cancelledToday, valueToday, week,
                count("select count(*) from vendor where status = 'APPROVED'"),
                count("select count(*) from user_role where role = 'CUSTOMER'"),
                count("select count(*) from app_user where created_at >= ?", start(today.minusDays(6))),
                attention);
    }

    /** @param days 7, 30 or 90 */
    @Transactional(readOnly = true)
    public VendorStats forVendor(UUID vendorId, int days) {
        int period = days <= 7 ? 7 : days <= 30 ? 30 : 90;
        LocalDate today = LocalDate.now(clock.withZone(INDIA));
        Timestamp from = start(today.minusDays(period - 1));
        String mine = " from shop_order where vendor_id = ? and created_at >= ?";
        long orders = count("select count(*)" + mine + " and status <> 'PENDING_PAYMENT'", vendorId, from);
        long completed = count("select count(*)" + mine + " and status = 'COMPLETED'", vendorId, from);
        long byShop = count("select count(*)" + mine + " and status = 'CANCELLED' and cancelled_by = 'VENDOR'"
                + " and accepted_at is null", vendorId, from);
        long missed = count("select count(*)" + mine + " and status = 'CANCELLED' and cancelled_by = 'SYSTEM'"
                + " and accepted_at is null", vendorId, from);
        long accepted = count("select count(*)" + mine + " and accepted_at is not null", vendorId, from);
        Double avgAccept = jdbc.queryForObject("select avg(extract(epoch from (accepted_at - created_at)) / 60)"
                + mine + " and accepted_at is not null", Double.class, vendorId, from);
        long sales = count("select coalesce(sum(items_total_minor), 0)" + mine + " and status = 'COMPLETED'",
                vendorId, from);
        long asked = accepted + byShop + missed;
        List<TopItem> top = jdbc.query("""
                select l.title, sum(l.quantity) qty, sum(l.line_total_minor) value
                from order_line l join shop_order o on o.id = l.shop_order_id
                where o.vendor_id = ? and o.created_at >= ? and o.status not in ('PENDING_PAYMENT', 'CANCELLED')
                group by l.title order by qty desc, value desc limit 5""",
                (rs, i) -> new TopItem(rs.getString(1), rs.getLong(2), rs.getLong(3)), vendorId, from);
        RatingSummary rating = reviews.summary(vendorId);
        return new VendorStats(period, orders, completed, byShop, missed,
                asked == 0 ? 0 : Math.round(accepted * 1000.0 / asked) / 1000.0,
                avgAccept == null ? null : Math.round(avgAccept * 10) / 10.0, sales,
                completed == 0 ? 0 : sales / completed,
                rating.count() == 0 ? null : rating.average(), rating.count(), follows.countFollowers(vendorId), top,
                days("select created_at, items_total_minor from shop_order where created_at >= ? and vendor_id = ? and "
                        + REAL_ORDER, vendorId, today, period));
    }

    /** Orders and value per day for the last [count] days, including days with none. */
    private List<Day> days(String sql, UUID vendorId, LocalDate today, int count) {
        LocalDate first = today.minusDays(count - 1);
        Map<LocalDate, long[]> byDay = new HashMap<>();
        Object[] args = vendorId == null ? new Object[] {start(first)} : new Object[] {start(first), vendorId};
        jdbc.query(sql, rs -> {
            LocalDate d = rs.getTimestamp(1).toInstant().atZone(INDIA).toLocalDate();
            long[] v = byDay.computeIfAbsent(d, k -> new long[2]);
            v[0]++;
            v[1] += rs.getLong(2);
        }, args);
        List<Day> out = new ArrayList<>();
        for (LocalDate d = first; !d.isAfter(today); d = d.plusDays(1)) {
            long[] v = byDay.getOrDefault(d, new long[2]);
            out.add(new Day(d, v[0], v[1]));
        }
        return out;
    }

    private long count(String sql, Object... args) {
        Long n = jdbc.queryForObject(sql, Long.class, args);
        return n == null ? 0 : n;
    }

    private static Timestamp start(LocalDate day) {
        return Timestamp.from(day.atStartOfDay(INDIA).toInstant());
    }
}
