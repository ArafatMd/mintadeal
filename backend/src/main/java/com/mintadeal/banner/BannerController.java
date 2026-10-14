package com.mintadeal.banner;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.banner.BannerDtos.BannerDto;
import com.mintadeal.banner.BannerDtos.BannerRequest;
import com.mintadeal.banner.BannerDtos.PublicBanner;
import com.mintadeal.banner.HomeBanner.Scope;

/** Home screen banners: managed by admins, read by everyone. */
@RestController
public class BannerController {

    private final BannerService service;

    public BannerController(BannerService service) {
        this.service = service;
    }

    /** @param scope NEARBY or CITYWIDE: which home view is asking */
    @GetMapping("/api/discovery/banners")
    public List<PublicBanner> live(@RequestParam(defaultValue = "NEARBY") Scope scope) {
        return service.live(scope == Scope.BOTH ? Scope.NEARBY : scope);
    }

    @GetMapping("/api/admin/banners")
    public List<BannerDto> all() {
        return service.all();
    }

    @PostMapping("/api/admin/banners")
    @ResponseStatus(HttpStatus.CREATED)
    public BannerDto create(@Valid @RequestBody BannerRequest req) {
        return service.create(req);
    }

    @PutMapping("/api/admin/banners/{id}")
    public BannerDto update(@PathVariable UUID id, @Valid @RequestBody BannerRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/api/admin/banners/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        service.delete(id);
    }
}
