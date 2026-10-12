package com.mintadeal.support;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

/** Stands in for Razorpay and 2Factor in tests and records every request it receives. */
public final class ProviderStub {

    public record Request(String method, String path, String body, String authorization) {
    }

    public static final ProviderStub INSTANCE = new ProviderStub();

    private final HttpServer server;
    public final List<Request> requests = new CopyOnWriteArrayList<>();
    private final AtomicInteger links = new AtomicInteger();
    public volatile String linkStatus = "created";
    public volatile boolean smsFails = false;
    public volatile boolean refundFails = false;
    public volatile boolean whatsappFails = false;
    public volatile String payoutStatus = "processing";

    private ProviderStub() {
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        server.createContext("/", this::handle);
        server.start();
    }

    public String baseUrl() {
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    public void reset() {
        requests.clear();
        linkStatus = "created";
        smsFails = false;
        refundFails = false;
        whatsappFails = false;
        payoutStatus = "processing";
    }

    private void handle(HttpExchange ex) throws IOException {
        String path = ex.getRequestURI().getRawPath();
        String query = ex.getRequestURI().getRawQuery();
        String body = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        requests.add(new Request(ex.getRequestMethod(), path + (query == null ? "" : "?" + query), body,
                ex.getRequestHeaders().getFirst("Authorization")));
        String auth = ex.getRequestHeaders().getFirst("Authorization");
        int status = 200;
        String out;
        if (path.startsWith("/v1/")) {
            if (auth == null || !auth.startsWith("Basic ")) {
                status = 401;
                out = "{\"error\":{\"description\":\"Authentication failed\"}}";
            } else if (path.equals("/v1/payment_links") && ex.getRequestMethod().equals("POST")) {
                int n = links.incrementAndGet();
                out = "{\"id\":\"plink_" + n + "\",\"short_url\":\"https://rzp.io/i/test" + n
                        + "\",\"status\":\"created\"}";
            } else if (path.equals("/v1/payment_links")) {
                out = "{\"payment_links\":[]}";
            } else if (path.endsWith("/cancel")) {
                out = "{\"status\":\"cancelled\"}";
            } else if (path.startsWith("/v1/payment_links/")) {
                out = "paid".equals(linkStatus)
                        ? "{\"status\":\"paid\",\"payments\":[{\"payment_id\":\"pay_stub\",\"status\":\"captured\"}]}"
                        : "{\"status\":\"" + linkStatus + "\",\"payments\":[]}";
            } else if (path.endsWith("/refund")) {
                if (refundFails) {
                    status = 400;
                    out = "{\"error\":{\"description\":\"The refund could not be processed\"}}";
                } else {
                    out = "{\"id\":\"rfnd_stub\",\"status\":\"processed\"}";
                }
            } else if (path.equals("/v1/contacts")) {
                out = "{\"id\":\"cont_1\"}";
            } else if (path.equals("/v1/fund_accounts")) {
                out = "{\"id\":\"fa_1\"}";
            } else if (path.equals("/v1/payouts")) {
                out = "{\"id\":\"pout_" + links.incrementAndGet() + "\",\"status\":\"processing\"}";
            } else if (path.startsWith("/v1/payouts/")) {
                out = "{\"id\":\"" + path.substring("/v1/payouts/".length()) + "\",\"status\":\"" + payoutStatus
                        + "\",\"utr\":\"UTR123456\",\"status_details\":{\"description\":\"Beneficiary bank down\"}}";
            } else {
                status = 404;
                out = "{}";
            }
        } else if (path.startsWith("/wa/")) {
            if (whatsappFails) {
                status = 400;
                out = "{\"error\":{\"message\":\"Template not approved\"}}";
            } else if (path.endsWith("/messages")) {
                out = "{\"messages\":[{\"id\":\"wamid.stub\"}]}";
            } else {
                out = "{\"display_phone_number\":\"+91 80000 00000\",\"verified_name\":\"Mintadeal\"}";
            }
        } else if (path.startsWith("/API/V1/")) {
            if (path.contains("/BAL/SMS")) {
                out = "{\"Status\":\"Success\",\"Details\":\"1000\"}";
            } else if (smsFails || path.contains("/badkey/")) {
                out = "{\"Status\":\"Error\",\"Details\":\"Invalid API Key\"}";
            } else {
                out = "{\"Status\":\"Success\",\"Details\":\"session-1\"}";
            }
        } else {
            status = 404;
            out = "{}";
        }
        byte[] bytes = out.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().add("Content-Type", "application/json");
        ex.sendResponseHeaders(status, bytes.length);
        ex.getResponseBody().write(bytes);
        ex.close();
    }
}
