package com.mintadeal.integrations;

import java.io.IOException;
import java.net.ProxySelector;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.mintadeal.common.ApiException;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/** Small JSON-over-HTTPS helper for payment and SMS providers. */
@Component
public class HttpJson {

    public record Response(int status, JsonNode body) {

        public boolean ok() {
            return status >= 200 && status < 300;
        }
    }

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .proxy(ProxySelector.getDefault())
            .build();
    private final ObjectMapper json;

    public HttpJson(ObjectMapper json) {
        this.json = json;
    }

    public Response get(String url, Map<String, String> headers) {
        return send(HttpRequest.newBuilder(URI.create(url)).GET(), headers);
    }

    public Response post(String url, Map<String, String> headers, Object body) {
        String payload = body == null ? "{}" : json.writeValueAsString(body);
        return send(HttpRequest.newBuilder(URI.create(url))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload)), headers);
    }

    public ObjectMapper mapper() {
        return json;
    }

    private Response send(HttpRequest.Builder builder, Map<String, String> headers) {
        headers.forEach(builder::header);
        builder.timeout(Duration.ofSeconds(15));
        try {
            HttpResponse<String> res = http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
            JsonNode body = res.body() == null || res.body().isBlank() ? json.createObjectNode() : parse(res.body());
            return new Response(res.statusCode(), body);
        } catch (IOException e) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "provider_unreachable",
                    "Could not reach " + builder.build().uri().getHost() + ". Try again in a moment.");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException(HttpStatus.BAD_GATEWAY, "provider_unreachable", "Request was interrupted");
        }
    }

    private JsonNode parse(String text) {
        try {
            return json.readTree(text);
        } catch (RuntimeException e) {
            return json.createObjectNode().put("raw", text.length() > 200 ? text.substring(0, 200) : text);
        }
    }
}
