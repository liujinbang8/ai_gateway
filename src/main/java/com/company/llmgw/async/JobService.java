package com.company.llmgw.async;

import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class JobService {
    private final Map<String, Map<String, Object>> jobs = new ConcurrentHashMap<>();

    public Mono<Map<String, Object>> createJob(String jobType, Object input) {
        String id = UUID.randomUUID().toString();
        Map<String, Object> record = new ConcurrentHashMap<>();
        record.put("job_id", id);
        record.put("job_type", jobType);
        record.put("status", "PENDING");
        record.put("created_at", Instant.now().toString());
        record.put("input", input);
        jobs.put(id, record);

        return Mono.just(record)
                .doOnNext(r -> {
                    r.put("status", "DONE");
                    r.put("completed_at", Instant.now().toString());
                });
    }

    public Mono<Map<String, Object>> getJob(String id) {
        return Mono.justOrEmpty(jobs.get(id));
    }
}
