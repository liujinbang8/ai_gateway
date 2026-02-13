package com.company.llmgw.dataplane;

import com.company.llmgw.auth.ApiPrincipal;
import com.company.llmgw.common.ApiException;
import com.company.llmgw.metering.QuotaService;
import com.company.llmgw.routing.RoutingService;
import com.company.llmgw.security.SecurityGovernanceService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class DataPlaneService {
    private final RoutingService routingService;
    private final SecurityGovernanceService governanceService;
    private final QuotaService quotaService;

    public DataPlaneService(RoutingService routingService, SecurityGovernanceService governanceService, QuotaService quotaService) {
        this.routingService = routingService;
        this.governanceService = governanceService;
        this.quotaService = quotaService;
    }

    public Map<String, Object> handle(ApiPrincipal principal, String protocol, String endpoint, Object payload, String contentForPolicy) {
        SecurityGovernanceService.GovernanceDecision decision = governanceService.evaluate(contentForPolicy);
        if (decision.blocked()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "SECURITY_BLOCKED", decision.reason());
        }
        quotaService.consume(principal, Math.max(contentForPolicy == null ? 1 : contentForPolicy.length(), 1));
        return routingService.dispatch(protocol, endpoint, payload);
    }
}
