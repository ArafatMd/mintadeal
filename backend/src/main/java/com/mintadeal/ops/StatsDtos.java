package com.mintadeal.ops;

import java.time.LocalDate;
import java.util.List;

public final class StatsDtos {

    private StatsDtos() {
    }

    /** One day of orders (not counting unpaid or cancelled ones) and their value. */
    public record Day(LocalDate date, long orders, long valueMinor) {
    }

    /** Things an admin should look at now. */
    public record Attention(long openTickets, long ordersWaitingForShop, long jobsWaitingForRider,
                            long failedNotifications24h, long failedRefunds, long failedPayouts,
                            long shopsWaitingForReview) {
    }

    /** The admin home: today, the last 7 days, and what needs attention. Days are Indian Standard Time. */
    public record AdminOverview(long ordersToday, long completedToday, long cancelledToday, long valueTodayMinor,
                                List<Day> last7Days, long liveShops, long customers, long newCustomersThisWeek,
                                Attention attention) {
    }

    public record TopItem(String title, long quantity, long valueMinor) {
    }

    /**
     * A shop's performance over the chosen period.
     *
     * @param acceptanceRate share of orders the shop accepted, of those it was asked to accept (0 to 1)
     * @param avgAcceptMinutes average time from order to acceptance, or null with no accepted orders
     */
    public record VendorStats(int days, long orders, long completed, long cancelledByShop, long missed,
                              double acceptanceRate, Double avgAcceptMinutes, long salesMinor, long avgOrderMinor,
                              Double rating, long ratingCount, long followers, List<TopItem> topItems,
                              List<Day> daily) {
    }
}
