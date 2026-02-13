package com.company.llmgw.admin;

import jakarta.validation.constraints.Pattern;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/admin/reports")
@Validated
public class AdminReportController {

    @GetMapping("/cost")
    public Map<String, Object> costReport(
            @RequestParam("period") @Pattern(regexp = "WEEK|MONTH|QUARTER") String period,
            @RequestParam("group_by") @Pattern(regexp = "USER_MODEL|DEPT_MODEL") String groupBy
    ) {
        return Map.of(
                "period", period,
                "group_by", groupBy,
                "items", java.util.List.of(
                        Map.of("dimension", "demo", "tokens", 1200, "cost", 2.31)
                )
        );
    }
}
