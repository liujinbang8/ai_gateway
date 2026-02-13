package com.company.llmgw.admin;

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
@Order(Ordered.HIGHEST_PRECEDENCE + 2)
public class AdminAuthFilter implements WebFilter {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        String path = exchange.getRequest().getPath().value();
        if (!path.startsWith("/admin")) {
            return chain.filter(exchange);
        }
        String subject = exchange.getRequest().getHeaders().getFirst("x-admin-subject");
        if (subject == null || subject.isBlank()) {
            return Mono.error(new ApiException(HttpStatus.UNAUTHORIZED, "ADMIN_UNAUTHORIZED", "Missing OIDC subject header"));
        }
        return chain.filter(exchange);
    }
}
