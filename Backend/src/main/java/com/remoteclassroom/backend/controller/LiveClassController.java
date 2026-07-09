package com.remoteclassroom.backend.controller;

import com.remoteclassroom.backend.model.LiveClass;
import com.remoteclassroom.backend.service.LiveClassService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/live")
public class LiveClassController {

    @Autowired
    private LiveClassService liveClassService;

    @Value("${AGORA_APP_ID}")
    private String appId;

    @PostMapping("/create")
    public ResponseEntity<com.remoteclassroom.backend.dto.LiveClassDTO> createClass(@jakarta.validation.Valid @RequestBody com.remoteclassroom.backend.dto.LiveClassRequest request, Authentication authentication) {
        System.out.println("📡 Received Live Class Create Request - Title: " + request.getTitle() + ", BatchId: " + request.getBatchId());
        String title = request.getTitle();
        Long batchId = request.getBatchId();
        String teacherEmail = authentication.getName();
        return ResponseEntity.ok(liveClassService.createClass(title, teacherEmail, batchId));
    }

    @PostMapping("/start")
    public ResponseEntity<com.remoteclassroom.backend.dto.LiveClassDTO> startClass(
            @RequestBody Map<String, Long> request,
            Authentication authentication) {
        Long classId = request.get("classId");
        return ResponseEntity.ok(liveClassService.startClass(classId, authentication.getName()));
    }

    @PostMapping("/end")
    public ResponseEntity<com.remoteclassroom.backend.dto.LiveClassDTO> endClass(
            @RequestBody Map<String, Long> request,
            Authentication authentication) {
        Long classId = request.get("classId");
        return ResponseEntity.ok(liveClassService.endClass(classId, authentication.getName()));
    }

    @GetMapping("/status/{batchId}")
    public ResponseEntity<com.remoteclassroom.backend.dto.LiveClassDTO> getLiveStatus(@PathVariable Long batchId) {
        com.remoteclassroom.backend.dto.LiveClassDTO lc = liveClassService.getLiveStatus(batchId);
        if (lc != null) {
            return ResponseEntity.ok(lc);
        }
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/join/{classId}")
    public ResponseEntity<?> joinClass(@PathVariable Long classId, Authentication auth) {
        liveClassService.joinClass(classId, auth.getName());
        return ResponseEntity.ok(Map.of("message", "Joined successfully"));
    }

    @PostMapping("/leave/{classId}")
    public ResponseEntity<?> leaveClass(@PathVariable Long classId, Authentication auth) {
        liveClassService.leaveClass(classId, auth.getName());
        return ResponseEntity.ok(Map.of("message", "Left successfully"));
    }

    @GetMapping("/attendance/{classId}")
    public ResponseEntity<?> getAttendance(@PathVariable Long classId, Authentication auth) {
        return ResponseEntity.ok(liveClassService.getAttendance(classId, auth.getName()));
    }

    @GetMapping("/token/{classId}")
    public ResponseEntity<?> getToken(
            @PathVariable Long classId,
            @RequestParam(defaultValue = "0") int uid,
            Authentication authentication) {
        String token = liveClassService.getAgoraToken(classId, uid, authentication.getName());
        LiveClass lc = liveClassService.getById(classId);
        
        return ResponseEntity.ok(Map.of(
            "token", token,
            "channel", lc.getMeetingId(),
            "meetingId", lc.getMeetingId(),
            "appId", appId
        ));
    }
}
