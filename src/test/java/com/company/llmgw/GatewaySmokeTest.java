package com.company.llmgw;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.AutoConfigureWebTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.reactive.server.WebTestClient;

@SpringBootTest
@AutoConfigureWebTestClient
class GatewaySmokeTest {

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void healthShouldWork() {
        webTestClient.get().uri("/healthz")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("ok");
    }

    @Test
    void openAiEndpointShouldRequireApiKey() {
        webTestClient.post().uri("/openai/v1/embeddings")
                .bodyValue("{\"input\":\"hello\"}")
                .header(HttpHeaders.CONTENT_TYPE, "application/json")
                .exchange()
                .expectStatus().isUnauthorized();
    }

    @Test
    void openAiEndpointShouldPassWithApiKey() {
        webTestClient.post().uri("/openai/v1/embeddings")
                .header(HttpHeaders.AUTHORIZATION, "Bearer openai-demo-key")
                .header(HttpHeaders.CONTENT_TYPE, "application/json")
                .bodyValue("{\"input\":\"hello\"}")
                .exchange()
                .expectStatus().isOk();
    }
}
