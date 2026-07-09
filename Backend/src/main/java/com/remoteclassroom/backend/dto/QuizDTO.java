package com.remoteclassroom.backend.dto;

import java.time.LocalDateTime;

public class QuizDTO {
    private Long id;
    private Long videoId;
    private Long batchId;
    private String difficulty;
    private Object questions;
    private Object hierarchy;
    private int totalQuestions;
    private LocalDateTime createdAt;

    public QuizDTO() {}

    public QuizDTO(Long id, Long videoId, Long batchId, String difficulty, Object questions, int totalQuestions, LocalDateTime createdAt) {
        this(id, videoId, batchId, difficulty, questions, null, totalQuestions, createdAt);
    }

    public QuizDTO(Long id, Long videoId, Long batchId, String difficulty, Object questions, Object hierarchy, int totalQuestions, LocalDateTime createdAt) {
        this.id = id;
        this.videoId = videoId;
        this.batchId = batchId;
        this.difficulty = difficulty;
        this.questions = questions;
        this.hierarchy = hierarchy;
        this.totalQuestions = totalQuestions;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getVideoId() { return videoId; }
    public void setVideoId(Long videoId) { this.videoId = videoId; }

    public Long getBatchId() { return batchId; }
    public void setBatchId(Long batchId) { this.batchId = batchId; }

    public String getDifficulty() { return difficulty; }
    public void setDifficulty(String difficulty) { this.difficulty = difficulty; }

    public Object getQuestions() { return questions; }
    public void setQuestions(Object questions) { this.questions = questions; }

    public Object getHierarchy() { return hierarchy; }
    public void setHierarchy(Object hierarchy) { this.hierarchy = hierarchy; }

    public int getTotalQuestions() { return totalQuestions; }
    public void setTotalQuestions(int totalQuestions) { this.totalQuestions = totalQuestions; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
