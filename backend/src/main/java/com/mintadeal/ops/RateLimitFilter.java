package com.mintadeal.ops;

import java.io.IOException;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.security.autoconfigure.web.servlet.SecurityFilterProperties;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Limits how fast one client can call the API, so a buggy app, a script or an attacker cannot overload it.
 * Counts live in memory, which is right for a single API server.
 */
@Component
// After Spring Security (and its CORS handling), so the apps can read the 429 message in a browser.
@Order(SecurityFilterProperties.DEFAULT_FILTER_ORDER + 1)
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);
    private static final long MINUTE = 60_000;
    private static final long TEN_MINUTES = 10 * MINUTE;
    private static final int MAX_TRACKED = 100_000;

    private record Rule(String name, long windowMs, int limit) {
    }

    private static final class Window {
        long start;
        int count;
    }

    private final RateLimitProperties props;
    private final Clock clock;
    private final Map<String, Window> windows = new ConcurrentHashMap<>();

    public RateLimitFilter(RateLimitProperties props, Clock clock) {
        this.props = props;
        this.clock = clock;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String path = req.getRequestURI();
        // Payment providers retry webhooks on their own schedule; never turn them away.
        return !props.enabled() || !path.startsWith("/api/") || path.startsWith("/api/webhooks/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String ip = clientIp(req);
        String who = req.getHeader(HttpHeaders.AUTHORIZATION) == null ? "ip:" + ip : "user:" + hash(req.getHeader(HttpHeaders.AUTHORIZATION));
        Rule general = new Rule("all", MINUTE, props.perMinute());
        Rule specific = specificRule(req);
        // Signed-in people are counted one by one: many phones share one IP on mobile networks.
        long retry = check(general, who);
        if (retry == 0 && specific != null) {
            retry = check(specific, specific.name().equals("auth") ? "ip:" + ip : who);
        }
        if (retry > 0) {
            log.warn("Rate limit hit: {} {} from {}", req.getMethod(), req.getRequestURI(), ip);
            res.setStatus(429);
            res.setHeader(HttpHeaders.RETRY_AFTER, Long.toString(retry));
            res.setContentType("application/problem+json");
            res.getOutputStream().write(("{\"type\":\"about:blank\",\"title\":\"Too Many Requests\",\"status\":429,"
                    + "\"detail\":\"Too many requests. Please wait a minute and try again.\",\"code\":\"rate_limited\"}")
                    .getBytes(StandardCharsets.UTF_8));
            return;
        }
        chain.doFilter(req, res);
    }

    private Rule specificRule(HttpServletRequest req) {
        String m = req.getMethod();
        String p = req.getRequestURI();
        if (p.startsWith("/api/auth/") && "POST".equals(m)) {
            return new Rule("auth", TEN_MINUTES, props.auth());
        }
        boolean write = "POST".equals(m) || "PUT".equals(m);
        if (write && (p.equals("/api/customer/checkout") || p.equals("/api/files") || p.startsWith("/api/support/")
                || p.endsWith("/review"))) {
            return new Rule("writes", TEN_MINUTES, props.writes());
        }
        return null;
    }

    /** Seconds until the client may try again, or 0 when the request is allowed. */
    private long check(Rule rule, String key) {
        long now = clock.millis();
        if (windows.size() > MAX_TRACKED) {
            windows.entrySet().removeIf(e -> now - e.getValue().start > TEN_MINUTES);
        }
        Window w = windows.computeIfAbsent(rule.name() + "|" + key, k -> new Window());
        synchronized (w) {
            if (now - w.start >= rule.windowMs()) {
                w.start = now;
                w.count = 0;
            }
            if (w.count >= rule.limit()) {
                return Math.max(1, (w.start + rule.windowMs() - now + 999) / 1000);
            }
            w.count++;
            return 0;
        }
    }

    /**
     * The real client address. The API sits behind Caddy on a private Docker network, and Caddy sets
     * X-Forwarded-For to the address it saw; that header is only trusted when the request came from a private address.
     */
    public static String clientIp(HttpServletRequest req) {
        String remote = req.getRemoteAddr();
        String forwarded = req.getHeader("X-Forwarded-For");
        if (forwarded == null || forwarded.isBlank() || !isPrivate(remote)) {
            return remote;
        }
        String[] hops = forwarded.split(",");
        return hops[hops.length - 1].trim();
    }

    private static boolean isPrivate(String ip) {
        try {
            InetAddress a = InetAddress.ofLiteral(ip);
            return a.isLoopbackAddress() || a.isSiteLocalAddress() || a.isLinkLocalAddress();
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private static String hash(String s) {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(d, 0, 12);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
