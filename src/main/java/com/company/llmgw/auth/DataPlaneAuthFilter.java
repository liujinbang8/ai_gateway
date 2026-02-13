package com.company.llmgw.auth;

import com.company.llmgw.common.ApiException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class DataPlaneAuthFilter implements WebFilter {
    public static final String PRINCIPAL_ATTR = "apiPrincipal";

    private final ApiKeyAuthService apiKeyAuthService;

    public DataPlaneAuthFilter(ApiKeyAuthService apiKeyAuthService) {
        this.apiKeyAuthService = apiKeyAuthService;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        String path = exchange.getRequest().getPath().value();
        if (!(path.startsWith("/openai/v1") || path.startsWith("/claude/v1"))) {
            return chain.filter(exchange);
        }

        String key = null;
        if (path.startsWith("/openai/v1")) {
            String bearer = exchange.getRequest().getHeaders().getFirst("Authorization");
            if (bearer != null && bearer.startsWith("Bearer ")) {
                key = bearer.substring("Bearer ".length());
            }
        } else if (path.startsWith("/claude/v1")) {
            key = exchange.getRequest().getHeaders().getFirst("x-api-key");
        }

        ApiPrincipal principal = apiKeyAuthService.authenticate(key);
        if (principal == null) {
            return Mono.error(new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Invalid API key"));
        }
        exchange.getAttributes().put(PRINCIPAL_ATTR, principal);
        return chain.filter(exchange);
    }
}
