package com.company.llmgw.auth;

public record ApiPrincipal(String ownerType, String ownerId, String deptId, long monthlyTokenCap) {
}
