package com.remoteclassroom.backend.controller;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import com.remoteclassroom.backend.dto.VideoDTO;
import com.remoteclassroom.backend.model.Video;
import com.remoteclassroom.backend.service.S3Service;
import com.remoteclassroom.backend.service.VideoService;

@RestController
@RequestMapping("/api/video")
public class VideoController {

    @Autowired
    private S3Service s3Service;

    @Autowired
    private VideoService videoService;

    // ================= UPLOAD =================
    @PreAuthorize("hasRole('TEACHER')")
    @PostMapping(value = "/upload", consumes = "multipart/form-data")
    public ResponseEntity<?> uploadVideo(
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file,
            @RequestParam("title") String title,
            @RequestParam Long batchId,
            @RequestParam(value = "transcript", required = false) String transcript,
            Authentication authentication
    ) {
        try {
            String fileUrl = s3Service.uploadFile(file);

            Video savedVideo = videoService.saveVideo(
                    title,
                    fileUrl,
                    authentication.getName(),
                    batchId,
                    transcript
            );

            return ResponseEntity.ok(savedVideo);

        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body("Upload failed: " + e.getMessage());
        }
    }

    // ================= PRESIGNED =================
    @PreAuthorize("hasRole('TEACHER')")
    @GetMapping("/upload-url")
    public ResponseEntity<?> getUploadUrl(@RequestParam String fileName) {

        String uniqueFileName = "video-" + UUID.randomUUID() + "-" + fileName;

        return ResponseEntity.ok(Map.of(
                "uploadUrl", s3Service.generatePresignedUrl(uniqueFileName),
                "fileUrl", s3Service.getFileUrl(uniqueFileName),
                "fileName", uniqueFileName
        ));
    }

    // ================= SAVE =================
    @PreAuthorize("hasRole('TEACHER')")
    @PostMapping("/save")
    public ResponseEntity<?> saveVideo(
            @RequestParam String title,
            @RequestParam String url,
            @RequestParam Long batchId,
            @RequestParam(required = false) String transcript,
            Authentication authentication
    ) {

        Video savedVideo = videoService.saveVideo(
                title,
                url,
                authentication.getName(),
                batchId,
                transcript
        );

        return ResponseEntity.ok(savedVideo);
    }

    // ================= DOWNLOAD =================
    @PreAuthorize("isAuthenticated()")
    @GetMapping("/download/{videoId}")
    public ResponseEntity<?> downloadVideo(@PathVariable Long videoId) {

        Video video = videoService.getById(videoId);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "data", Map.of(
                        "downloadUrl", s3Service.generateDownloadUrl(video.getUrl(), video.getTitle())
                )
        ));
    }

    // ================= PLAYBACK =================
    @PreAuthorize("isAuthenticated()")
    @GetMapping("/playback/{videoId}")
    public ResponseEntity<?> getPlaybackUrl(@PathVariable Long videoId) {

        try {
            Video video = videoService.getById(videoId);

            if (video == null || video.getUrl() == null) {
                return ResponseEntity.ok(Map.of(
                        "success", false,
                        "message", "Video not found or not ready",
                        "data", Map.of()
                ));
            }

            // 🔥 FIX: Use signed playback URL
            String playbackUrl = s3Service.generatePlaybackUrl(video.getUrl());

            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "data", Map.of(
                            "url", playbackUrl,
                            "title", video.getTitle()
                    )
            ));

        } catch (Exception e) {
            return ResponseEntity.ok(Map.of(
                    "success", false,
                    "message", "Playback failed: " + e.getMessage(),
                    "data", Map.of()
            ));
        }
    }

    // ================= LIST =================
    @GetMapping("/all")
    public List<VideoDTO> getAllVideos() {
        return videoService.getAllVideosDTO();
    }

    @GetMapping("/my")
    public List<VideoDTO> getMyVideos(Authentication authentication) {
        return videoService.getMyVideosDTO(authentication.getName());
    }

    @PreAuthorize("isAuthenticated()")
    @GetMapping("/batch/{batchId}")
    public ResponseEntity<?> getVideosByBatch(
            @PathVariable Long batchId,
            Authentication authentication
    ) {
        try {
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "data", videoService.getVideosByBatchDTO(batchId, authentication.getName())
            ));
        } catch (RuntimeException e) {
            HttpStatus status = e.getMessage() != null && e.getMessage().contains("Access denied")
                    ? HttpStatus.FORBIDDEN
                    : HttpStatus.BAD_REQUEST;
            return ResponseEntity.status(status).body(Map.of(
                    "success", false,
                    "message", e.getMessage(),
                    "data", List.of()
            ));
        }
    }
}
