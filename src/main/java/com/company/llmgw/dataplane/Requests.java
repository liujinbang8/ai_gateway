package com.company.llmgw.dataplane;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;
import java.util.Map;

public class Requests {
    public record ChatMessage(@NotBlank String role, @NotBlank String content) {}
    public record OpenAiChatRequest(@NotEmpty List<ChatMessage> messages, boolean stream) {}
    public record EmbeddingRequest(@NotBlank String input) {}
    public record RerankRequest(@NotBlank String input, @NotEmpty List<String> documents) {}
    public record ClaudeMessageRequest(Integer max_tokens, @NotEmpty List<ChatMessage> messages) {}
    public record JobRequest(@NotBlank String job_type, Map<String, Object> input) {}
}
