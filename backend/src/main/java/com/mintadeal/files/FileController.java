package com.mintadeal.files;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.core.io.PathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mintadeal.common.ApiException;

@RestController
public class FileController {

    private static final Pattern NAME = Pattern.compile("[0-9a-f\\-]{36}\\.(jpg|png|webp)");

    private final FileProperties props;

    public FileController(FileProperties props) throws IOException {
        this.props = props;
        Files.createDirectories(Path.of(props.directory()));
    }

    public record Uploaded(String url) {
    }

    @PostMapping("/api/files")
    @ResponseStatus(HttpStatus.CREATED)
    public Uploaded upload(@RequestParam("file") MultipartFile file) throws IOException {
        String ext;
        try (InputStream in = file.getInputStream()) {
            ext = detectImage(in.readNBytes(12));
        }
        String name = UUID.randomUUID() + "." + ext;
        try (InputStream in = file.getInputStream()) {
            Files.copy(in, Path.of(props.directory()).resolve(name), StandardCopyOption.REPLACE_EXISTING);
        }
        return new Uploaded(props.publicBaseUrl() + "/files/" + name);
    }

    @GetMapping("/files/{name}")
    public ResponseEntity<Resource> serve(@PathVariable String name) {
        if (!NAME.matcher(name).matches()) {
            throw ApiException.notFound("File");
        }
        Path path = Path.of(props.directory()).resolve(name);
        if (!Files.exists(path)) {
            throw ApiException.notFound("File");
        }
        MediaType type = switch (name.substring(name.lastIndexOf('.') + 1)) {
            case "png" -> MediaType.IMAGE_PNG;
            case "webp" -> MediaType.parseMediaType("image/webp");
            default -> MediaType.IMAGE_JPEG;
        };
        return ResponseEntity.ok().contentType(type)
                .cacheControl(CacheControl.maxAge(java.time.Duration.ofDays(30)).cachePublic())
                .body(new PathResource(path));
    }

    /** Trusts the file's bytes, not its name or declared content type. */
    static String detectImage(byte[] h) {
        if (h.length >= 3 && (h[0] & 0xFF) == 0xFF && (h[1] & 0xFF) == 0xD8 && (h[2] & 0xFF) == 0xFF) {
            return "jpg";
        }
        if (h.length >= 8 && Arrays.equals(Arrays.copyOf(h, 8),
                new byte[] {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'})) {
            return "png";
        }
        if (h.length >= 12 && h[0] == 'R' && h[1] == 'I' && h[2] == 'F' && h[3] == 'F'
                && h[8] == 'W' && h[9] == 'E' && h[10] == 'B' && h[11] == 'P') {
            return "webp";
        }
        throw ApiException.badRequest("unsupported_image", "Upload a JPEG, PNG or WebP image");
    }
}
