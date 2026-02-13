package com.company.llmgw.routing;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Map;

@Service
public class RoutingService {
    public Map<String, Object> dispatch(String vendorProtocol, String endpoint, Object payload) {
        return Map.of(
                "protocol", vendorProtocol,
                "endpoint", endpoint,
                "result", "ok",
                "echo", payload,
                "created_at", Instant.now().toString()
        );
    }
}
