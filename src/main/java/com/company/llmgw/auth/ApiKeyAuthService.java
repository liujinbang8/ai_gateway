package com.company.llmgw.auth;

import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ApiKeyAuthService {
    private final GatewaySecurityProperties properties;
    private final Map<String, ApiPrincipal> keyStore = new ConcurrentHashMap<>();

    public ApiKeyAuthService(GatewaySecurityProperties properties) {
        this.properties = properties;
        seed();
    }

    public ApiPrincipal authenticate(String plainKey) {
        if (plainKey == null || plainKey.isBlank()) {
            return null;
        }
        return keyStore.get(sha256Hex(plainKey + properties.getServerSalt()));
    }

    private void seed() {
        properties.getApiKeys().forEach(seed -> {
            if (seed.getPlainKey() != null && !seed.getPlainKey().isBlank()) {
                String hashed = sha256Hex(seed.getPlainKey() + properties.getServerSalt());
                keyStore.put(hashed, new ApiPrincipal(seed.getOwnerType(), seed.getOwnerId(), seed.getDeptId(), seed.getMonthlyTokenCap()));
            }
        });
    }

    private String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
