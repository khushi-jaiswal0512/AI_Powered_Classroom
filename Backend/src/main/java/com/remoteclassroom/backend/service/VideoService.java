package com.remoteclassroom.backend.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.remoteclassroom.backend.dto.VideoDTO;
import com.remoteclassroom.backend.model.*;
import com.remoteclassroom.backend.repository.*;

@Service
public class VideoService {

    @Autowired private VideoRepository videoRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private BatchRepository batchRepository;
    @Autowired private EnrollmentRepository enrollmentRepository;

    // 🔥 ADD THIS
    @Autowired private TranscriptionService transcriptionService;

    // ================= SAVE =================
    public Video saveVideo(String title, String url, String username, Long batchId, String transcript) {

        User teacher = userRepository.findByEmail(username)
                .orElseThrow(() -> new RuntimeException("Teacher not found"));

        // 🔥 FIX: SAFE batch handling
        Batch batch;

        if (batchId == null || batchId == 0) {
            // fallback to teacher’s first batch
            batch = batchRepository.findByTeacher(teacher)
                    .stream()
                    .findFirst()
                    .orElseThrow(() -> new RuntimeException("No batch found for teacher"));
        } else {
            batch = batchRepository.findById(batchId)
                    .orElseThrow(() -> new RuntimeException("Batch not found"));
        }

        Video video = new Video();
        video.setTitle(title);
        video.setUrl(url);
        video.setTranscript(transcript);
        video.setTeacher(teacher);
        video.setBatch(batch);

        Video savedVideo = videoRepository.save(video);

        // 🔥🔥🔥 CRITICAL FIX — TRIGGER TRANSCRIPTION
        transcriptionService.transcribeVideoAsync(savedVideo.getId());

        return savedVideo;
    }

    // ================= GET ALL =================
    @Transactional(readOnly = true)
    public List<VideoDTO> getAllVideosDTO() {
        return videoRepository.findAll()
                .stream()
                .map(this::mapToDTO)
                .toList();
    }
    public Video getById(Long id) {
    return videoRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Video not found"));
}

    // ================= GET MY =================
    @Transactional(readOnly = true)
    public List<VideoDTO> getMyVideosDTO(String username) {
        return videoRepository.findByTeacherEmail(username)
                .stream()
                .map(this::mapToDTO)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<VideoDTO> getVideosByBatchDTO(Long batchId, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Batch batch = batchRepository.findById(batchId)
                .orElseThrow(() -> new RuntimeException("Batch not found"));

        boolean isTeacherOwner = batch.getTeacher() != null
                && batch.getTeacher().getId() != null
                && batch.getTeacher().getId().equals(user.getId());
        boolean isEnrolledStudent = enrollmentRepository.findByStudentAndBatch(user, batch).isPresent();

        if (!isTeacherOwner && !isEnrolledStudent) {
            throw new RuntimeException("Access denied for this batch");
        }

        return videoRepository.findByBatchId(batchId)
                .stream()
                .map(this::mapToDTO)
                .toList();
    }

    // ================= GET BY ID =================
    private VideoDTO mapToDTO(Video v) {

    Long batchId = null;
    String batchName = null;
    String batchCode = null;

    try {
        if (v.getBatch() != null && v.getBatch().getId() != null && v.getBatch().getId() != 0) {
            batchId = v.getBatch().getId();
            batchName = v.getBatch().getName();
            batchCode = v.getBatch().getBatchCode();
        }
    } catch (Exception e) {
        System.out.println("⚠️ Skipping invalid batch for videoId=" + v.getId());
    }

    return new VideoDTO(
            v.getId(),
            v.getTitle(),
            v.getUrl(),
            v.getTeacher() != null ? v.getTeacher().getName() : null,
            batchId,
            batchName,
            batchCode,
            v.getUploadedAt(),
            v.getTranscript()
    );
}
}
