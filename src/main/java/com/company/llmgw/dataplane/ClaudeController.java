package com.company.llmgw.dataplane;

import com.company.llmgw.auth.ApiPrincipal;
import com.company.llmgw.auth.DataPlaneAuthFilter;
import com.company.llmgw.common.ApiException;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/claude/v1")
public class ClaudeController {
    private final DataPlaneService dataPlaneService;

    public ClaudeController(DataPlaneService dataPlaneService) {
        this.dataPlaneService = dataPlaneService;
    }

    @PostMapping("/messages")
    public Object messages(@Valid @RequestBody Requests.ClaudeMessageRequest request,
                           @RequestParam(name = "stream", defaultValue = "false") boolean stream,
                           ServerWebExchange exchange) {
        ApiPrincipal principal = principal(exchange);
        String content = request.messages().stream().map(Requests.ChatMessage::content).reduce("", String::concat);
        if (stream) {
            return Flux.fromIterable(List.of("claude-chunk-1", "claude-chunk-2", "[DONE]"))
                    .map(c -> ServerSentEvent.builder(Map.of("data", c)).build());
        }
        return dataPlaneService.handle(principal, "claude", "messages", request, content);
    }

    @PostMapping("/embeddings")
    public Map<String, Object> embeddings(@Valid @RequestBody Requests.EmbeddingRequest request, ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "claude", "embeddings", request, request.input());
    }

    @PostMapping("/rerank")
    public Map<String, Object> rerank(@RequestBody Map<String, Object> request, ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "claude", "rerank", request, request.toString());
    }

    @PostMapping(value = "/ocr", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Map<String, Object> ocr(ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "claude", "ocr", Map.of("status", "accepted"), "ocr");
    }

    private ApiPrincipal principal(ServerWebExchange exchange) {
        ApiPrincipal principal = exchange.getAttribute(DataPlaneAuthFilter.PRINCIPAL_ATTR);
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Missing principal");
        }
        return principal;
    }
}
