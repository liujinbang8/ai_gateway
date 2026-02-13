package com.company.llmgw.security;

import com.company.llmgw.auth.GatewaySecurityProperties;
import org.springframework.stereotype.Service;

@Service
public class SecurityGovernanceService {
    private final GatewaySecurityProperties properties;

    public SecurityGovernanceService(GatewaySecurityProperties properties) {
        this.properties = properties;
    }

    public GovernanceDecision evaluate(String content) {
        if (content == null) {
            return GovernanceDecision.allow();
        }
        String normalized = content.toLowerCase();
        return properties.getSensitiveWords().stream()
                .filter(word -> normalized.contains(word.toLowerCase()))
                .findFirst()
                .map(w -> GovernanceDecision.block("Sensitive word detected: " + w))
                .orElseGet(GovernanceDecision::allow);
    }

    public record GovernanceDecision(boolean blocked, String reason) {
        static GovernanceDecision allow() { return new GovernanceDecision(false, "ALLOW"); }
        static GovernanceDecision block(String reason) { return new GovernanceDecision(true, reason); }
    }
}
