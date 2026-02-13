package com.company.llmgw.dataplane;

import com.company.llmgw.async.JobService;
import com.company.llmgw.auth.ApiPrincipal;
import com.company.llmgw.auth.DataPlaneAuthFilter;
import com.company.llmgw.common.ApiException;
import com.company.llmgw.common.RequestIdWebFilter;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/openai/v1")
public class OpenAiController {
    private final DataPlaneService dataPlaneService;
    private final JobService jobService;

    public OpenAiController(DataPlaneService dataPlaneService, JobService jobService) {
        this.dataPlaneService = dataPlaneService;
        this.jobService = jobService;
    }

    @PostMapping("/chat/completions")
    public Object chatCompletions(@Valid @RequestBody Requests.OpenAiChatRequest request, ServerWebExchange exchange) {
        ApiPrincipal principal = principal(exchange);
        String content = request.messages().stream().map(Requests.ChatMessage::content).reduce("", String::concat);
        if (request.stream()) {
            return Flux.fromIterable(List.of("chunk-1", "chunk-2", "[DONE]"))
                    .map(c -> ServerSentEvent.builder(Map.of("data", c)).build());
        }
        return dataPlaneService.handle(principal, "openai", "chat/completions", request, content);
    }

    @PostMapping("/embeddings")
    public Map<String, Object> embeddings(@Valid @RequestBody Requests.EmbeddingRequest request, ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "openai", "embeddings", request, request.input());
    }

    @PostMapping("/rerank")
    public Map<String, Object> rerank(@Valid @RequestBody Requests.RerankRequest request, ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "openai", "rerank", request, request.input());
    }

    @PostMapping("/responses")
    public Map<String, Object> responses(@RequestBody Map<String, Object> request, ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "openai", "responses", request, request.toString());
    }

    @PostMapping(value = "/ocr", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Map<String, Object> ocr(ServerWebExchange exchange) {
        return dataPlaneService.handle(principal(exchange), "openai", "ocr", Map.of("status", "accepted"), "ocr");
    }

    @PostMapping("/jobs")
    public Mono<Map<String, Object>> createJob(@Valid @RequestBody Requests.JobRequest request, ServerWebExchange exchange) {
        principal(exchange);
        return jobService.createJob(request.job_type(), request.input());
    }

    @GetMapping("/jobs/{id}")
    public Mono<Map<String, Object>> getJob(@PathVariable String id, ServerWebExchange exchange) {
        principal(exchange);
        return jobService.getJob(id).switchIfEmpty(Mono.error(new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "job not found")));
    }

    private ApiPrincipal principal(ServerWebExchange exchange) {
        ApiPrincipal principal = exchange.getAttribute(DataPlaneAuthFilter.PRINCIPAL_ATTR);
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Missing principal");
        }
        return principal;
    }
}
