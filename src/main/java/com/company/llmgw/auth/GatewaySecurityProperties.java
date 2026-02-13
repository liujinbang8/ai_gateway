package com.company.llmgw.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.ArrayList;
import java.util.List;

@ConfigurationProperties(prefix = "llmgw.security")
public class GatewaySecurityProperties {
    private String serverSalt = "change-me-in-prod";
    private List<String> sensitiveWords = new ArrayList<>(List.of("password", "secret", "token"));
    private List<ApiKeySeed> apiKeys = new ArrayList<>();

    public String getServerSalt() { return serverSalt; }
    public void setServerSalt(String serverSalt) { this.serverSalt = serverSalt; }
    public List<String> getSensitiveWords() { return sensitiveWords; }
    public void setSensitiveWords(List<String> sensitiveWords) { this.sensitiveWords = sensitiveWords; }
    public List<ApiKeySeed> getApiKeys() { return apiKeys; }
    public void setApiKeys(List<ApiKeySeed> apiKeys) { this.apiKeys = apiKeys; }

    public static class ApiKeySeed {
        private String plainKey;
        private String ownerType = "USER";
        private String ownerId;
        private String deptId;
        private long monthlyTokenCap = 1_000_000L;

        public String getPlainKey() { return plainKey; }
        public void setPlainKey(String plainKey) { this.plainKey = plainKey; }
        public String getOwnerType() { return ownerType; }
        public void setOwnerType(String ownerType) { this.ownerType = ownerType; }
        public String getOwnerId() { return ownerId; }
        public void setOwnerId(String ownerId) { this.ownerId = ownerId; }
        public String getDeptId() { return deptId; }
        public void setDeptId(String deptId) { this.deptId = deptId; }
        public long getMonthlyTokenCap() { return monthlyTokenCap; }
        public void setMonthlyTokenCap(long monthlyTokenCap) { this.monthlyTokenCap = monthlyTokenCap; }
    }
}
