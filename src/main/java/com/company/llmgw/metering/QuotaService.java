package com.company.llmgw.metering;

import com.company.llmgw.auth.ApiPrincipal;
import com.company.llmgw.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class QuotaService {
    private final Map<String, AtomicLong> monthlyTokens = new ConcurrentHashMap<>();

    public void consume(ApiPrincipal principal, long tokens) {
        String key = principal.ownerType() + ":" + principal.ownerId();
        long used = monthlyTokens.computeIfAbsent(key, s -> new AtomicLong()).addAndGet(tokens);
        if (used > principal.monthlyTokenCap()) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "QUOTA_EXCEEDED", "Monthly token cap exceeded");
        }
    }
}
