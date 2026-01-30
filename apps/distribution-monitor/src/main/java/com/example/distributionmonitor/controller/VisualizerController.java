// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


package com.example.distributionmonitor.controller;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;

import java.util.HashMap;
import java.util.Map;

@Controller
public class VisualizerController {

    @Value("${pod.id}")
    private String podId;

    @Value("${app.version}")
    private String appVersion;

    @GetMapping("/")
    public String index(HttpServletRequest request, HttpServletResponse response, Model model) {
        // Record current Pod ID and version in cookies
        Map<String, Integer> podCounts = getPodCountsFromCookies(request);
        String cookieKey = podId + ":" + appVersion;
        podCounts.put(cookieKey, podCounts.getOrDefault(cookieKey, 0) + 1);
        
        // Update cookies
        for (Map.Entry<String, Integer> entry : podCounts.entrySet()) {
            Cookie cookie = new Cookie("pod_" + entry.getKey().replace(":", "_"), String.valueOf(entry.getValue()));
            cookie.setMaxAge(60 * 60 * 24 * 365); // 1 year
            cookie.setPath("/");
            response.addCookie(cookie);
        }

        model.addAttribute("currentPodId", podId);
        model.addAttribute("currentVersion", appVersion);
        model.addAttribute("podCounts", podCounts);
        model.addAttribute("totalRequests", podCounts.values().stream().mapToInt(Integer::intValue).sum());

        return "index";
    }

    @PostMapping("/clear")
    public String clearCookies(HttpServletRequest request, HttpServletResponse response) {
        // Clear all cookies
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if (cookie.getName().startsWith("pod_")) {
                    Cookie clearCookie = new Cookie(cookie.getName(), "");
                    clearCookie.setMaxAge(0);
                    clearCookie.setPath("/");
                    response.addCookie(clearCookie);
                }
            }
        }
        return "redirect:/";
    }

    private Map<String, Integer> getPodCountsFromCookies(HttpServletRequest request) {
        Map<String, Integer> counts = new HashMap<>();
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if (cookie.getName().startsWith("pod_")) {
                    String key = cookie.getName().substring(4).replace("_", ":");
                    try {
                        counts.put(key, Integer.parseInt(cookie.getValue()));
                    } catch (NumberFormatException e) {
                        // Ignore invalid cookies
                    }
                }
            }
        }
        return counts;
    }
}
