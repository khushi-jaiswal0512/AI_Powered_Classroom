package com.remoteclassroom.backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.remoteclassroom.backend.model.Batch;
import com.remoteclassroom.backend.model.LiveClass;
import com.remoteclassroom.backend.model.User;
import com.remoteclassroom.backend.repository.AttendanceRepository;
import com.remoteclassroom.backend.repository.BatchRepository;
import com.remoteclassroom.backend.repository.EnrollmentRepository;
import com.remoteclassroom.backend.repository.LiveClassRepository;
import com.remoteclassroom.backend.repository.UserRepository;

import io.agora.media.RtcTokenBuilder;
import org.springframework.beans.factory.annotation.Value;

import com.remoteclassroom.backend.model.Attendance;

@Service
public class LiveClassService {

    @Autowired private LiveClassRepository liveClassRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private BatchRepository batchRepository;
    @Autowired private AttendanceRepository attendanceRepository;
    @Autowired private EnrollmentRepository enrollmentRepository;

    @Value("${AGORA_APP_ID}")
    private String appId;

    @Value("${AGORA_APP_CERTIFICATE}")
    private String appCertificate;

    // ================= CREATE =================
    @Transactional
    public com.remoteclassroom.backend.dto.LiveClassDTO createClass(String title, String teacherEmail, Long batchId) {

        User teacher = userRepository.findByEmail(teacherEmail)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Batch batch = batchRepository.findById(batchId)
                .orElseThrow(() -> new RuntimeException("Batch not found"));

        if (!batch.getTeacher().getEmail().equals(teacherEmail)) {
            throw new RuntimeException("Unauthorized: Not your batch");
        }

        LiveClass lc = new LiveClass();
        lc.setTitle(title);
        lc.setTeacher(teacher);
        lc.setBatch(batch);
        lc.setLive(false);
        lc.setMeetingId(UUID.randomUUID().toString());

        return mapToDTO(liveClassRepository.save(lc));
    }

    // ================= START =================
    @Transactional
    public com.remoteclassroom.backend.dto.LiveClassDTO startClass(Long classId, String teacherEmail) {

        LiveClass lc = liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));
        ensureTeacherOwner(lc, teacherEmail);

        lc.setLive(true);
        lc.setStartTime(LocalDateTime.now());

        return mapToDTO(liveClassRepository.save(lc));
    }

    // ================= END =================
    @Transactional
    public com.remoteclassroom.backend.dto.LiveClassDTO endClass(Long classId, String teacherEmail) {

        LiveClass lc = liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));
        ensureTeacherOwner(lc, teacherEmail);

        lc.setLive(false);

        List<Attendance> list = attendanceRepository.findByLiveClass(lc);

        for (Attendance a : list) {
            if (a.getJoinTime() != null && a.getLeaveTime() == null) {

                a.setLeaveTime(LocalDateTime.now());

                long mins = java.time.Duration
                        .between(a.getJoinTime(), a.getLeaveTime())
                        .toMinutes();

                if (mins >= 5) {
                    a.setPresent(true);
                }

                attendanceRepository.save(a);
            }
        }

        return mapToDTO(liveClassRepository.save(lc));
    }

    // ================= STATUS =================
    public com.remoteclassroom.backend.dto.LiveClassDTO getLiveStatus(Long batchId) {
        return liveClassRepository.findFirstByBatchIdAndIsLiveTrue(batchId)
                .map(this::mapToDTO)
                .orElse(null);
    }

    // ================= DTO =================
    private com.remoteclassroom.backend.dto.LiveClassDTO mapToDTO(LiveClass lc) {

        String teacherName = lc.getTeacher() != null ? lc.getTeacher().getName() : "Unknown";
        String batchName = lc.getBatch() != null ? lc.getBatch().getName() : "Unknown";

        return new com.remoteclassroom.backend.dto.LiveClassDTO(
                lc.getId(),
                lc.getTitle(),
                lc.isLive(),
                lc.getMeetingId(),
                lc.getStartTime(),
                teacherName,
                batchName
        );
    }

    // ================= JOIN =================
    @Transactional
    public void joinClass(Long classId, String email) {

        User student = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!student.getRole().contains("STUDENT")) {
            throw new RuntimeException("Only students can join");
        }

        LiveClass liveClass = liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));

        if (!liveClass.isLive()) {
            throw new RuntimeException("Class not live");
        }

        Attendance attendance = attendanceRepository
                .findByLiveClassAndStudent(liveClass, student)
                .orElse(null);

        if (attendance == null) {
            attendance = new Attendance();
            attendance.setLiveClass(liveClass);
            attendance.setStudent(student);
            attendance.setJoinTime(LocalDateTime.now());
            attendance.setPresent(false);
        } else {
            // 🔥 FIX: DO NOT overwrite join time
            if (attendance.getJoinTime() == null) {
                attendance.setJoinTime(LocalDateTime.now());
            }
            attendance.setLeaveTime(null);
        }

        attendanceRepository.save(attendance);
    }

    // ================= LEAVE =================
    @Transactional
    public void leaveClass(Long classId, String email) {

        User student = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        LiveClass liveClass = liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));

        Attendance attendance = attendanceRepository
                .findByLiveClassAndStudent(liveClass, student)
                .orElse(null);

        if (attendance == null || attendance.getJoinTime() == null) return;

        attendance.setLeaveTime(LocalDateTime.now());

        long mins = java.time.Duration
                .between(attendance.getJoinTime(), attendance.getLeaveTime())
                .toMinutes();

        if (mins >= 5) {
            attendance.setPresent(true);
        }

        attendanceRepository.save(attendance);
    }

    // ================= ATTENDANCE =================
    public List<com.remoteclassroom.backend.dto.AttendanceDTO> getAttendance(Long classId, String teacherEmail) {

        LiveClass liveClass = liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));

        if (!liveClass.getTeacher().getEmail().equals(teacherEmail)) {
            throw new RuntimeException("Unauthorized");
        }

        return attendanceRepository.findByLiveClass(liveClass)
                .stream()
                .map(a -> new com.remoteclassroom.backend.dto.AttendanceDTO(
                        a.getStudent() != null ? a.getStudent().getName() : "Unknown",
                        a.getStudent() != null ? a.getStudent().getEmail() : "Unknown",
                        a.getJoinTime(),
                        a.getLeaveTime()
                ))
                .toList();
    }

    // ================= GET =================
    public LiveClass getById(Long classId) {
        return liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));
    }

    // ================= TOKEN =================
    public String getAgoraToken(Long classId, int uid, String email) {

        LiveClass lc = liveClassRepository.findById(classId)
                .orElseThrow(() -> new RuntimeException("Class not found"));
        ensureCanAccessClass(lc, email);

        if (appId == null || appCertificate == null) {
            throw new RuntimeException("Agora config missing");
        }

        int timestamp = (int) (System.currentTimeMillis() / 1000 + 3600);

        return new RtcTokenBuilder().buildTokenWithUid(
                appId,
                appCertificate,
                lc.getMeetingId(),
                uid,
                RtcTokenBuilder.Role.Role_Publisher,
                timestamp
        );
    }

    private void ensureTeacherOwner(LiveClass liveClass, String teacherEmail) {
        if (liveClass.getTeacher() == null || !liveClass.getTeacher().getEmail().equals(teacherEmail)) {
            throw new RuntimeException("Unauthorized");
        }
    }

    private void ensureCanAccessClass(LiveClass liveClass, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (liveClass.getTeacher() != null && liveClass.getTeacher().getId().equals(user.getId())) {
            return;
        }

        if (liveClass.getBatch() != null
                && enrollmentRepository.findByStudentAndBatch(user, liveClass.getBatch()).isPresent()) {
            return;
        }

        throw new RuntimeException("Unauthorized");
    }
}
