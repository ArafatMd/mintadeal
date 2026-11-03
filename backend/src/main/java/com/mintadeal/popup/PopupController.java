package com.mintadeal.popup;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.popup.PopupDtos.AdminPopup;
import com.mintadeal.popup.PopupDtos.AgainRequest;
import com.mintadeal.popup.PopupDtos.LimitsRequest;
import com.mintadeal.popup.PopupDtos.SellerLimits;
import com.mintadeal.popup.PopupDtos.SettingsDto;
import com.mintadeal.popup.PopupDtos.Me;
import com.mintadeal.popup.PopupDtos.MoveRequest;
import com.mintadeal.popup.PopupDtos.NameRequest;
import com.mintadeal.popup.PopupDtos.PublicPopup;
import com.mintadeal.popup.PopupDtos.ReasonRequest;
import com.mintadeal.popup.PopupDtos.ReportRequest;
import com.mintadeal.popup.PopupDtos.StartRequest;
import com.mintadeal.popup.PopupService.AdminFilter;

@RestController
public class PopupController {

    private final PopupService service;

    public PopupController(PopupService service) {
        this.service = service;
    }

    // Seller: any signed-in person can open a stall.

    @GetMapping("/api/popup/me")
    public Me me() {
        return service.me(CurrentUser.id());
    }

    @PutMapping("/api/popup/me")
    public Me rename(@Valid @RequestBody NameRequest req) {
        return service.rename(CurrentUser.id(), req.name());
    }

    @PostMapping("/api/popup/stalls")
    @ResponseStatus(HttpStatus.CREATED)
    public Me start(@Valid @RequestBody StartRequest req) {
        return service.start(CurrentUser.id(), req);
    }

    @PostMapping("/api/popup/stalls/{id}/again")
    @ResponseStatus(HttpStatus.CREATED)
    public Me again(@PathVariable UUID id, @Valid @RequestBody AgainRequest req) {
        return service.again(CurrentUser.id(), id, req.latitude(), req.longitude(), req.days(), req.stallName());
    }

    @PostMapping("/api/popup/stalls/{id}/check-payment")
    public Me checkPayment(@PathVariable UUID id) {
        return service.checkPayment(CurrentUser.id(), id);
    }

    @PostMapping("/api/popup/stalls/{id}/move")
    public Me move(@PathVariable UUID id, @Valid @RequestBody MoveRequest req) {
        return service.move(CurrentUser.id(), id, req.latitude(), req.longitude());
    }

    @PostMapping("/api/popup/stalls/{id}/stop")
    public Me stop(@PathVariable UUID id) {
        return service.stop(CurrentUser.id(), id);
    }

    // Customers.

    @GetMapping("/api/discovery/popups")
    public List<PublicPopup> nearby(@RequestParam double lat, @RequestParam double lng) {
        return service.nearby(lat, lng);
    }

    @GetMapping("/api/discovery/popups/{id}")
    public PublicPopup one(@PathVariable UUID id, @RequestParam(required = false) Double lat,
                           @RequestParam(required = false) Double lng) {
        return service.one(id, lat, lng);
    }

    /** The customer app tells us a stall was opened, or Call, WhatsApp or Directions was tapped. */
    @PostMapping("/api/discovery/popups/{id}/events")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void react(@PathVariable UUID id, @Valid @RequestBody PopupDtos.ReactionRequest req) {
        service.react(id, req.type());
    }

    @GetMapping("/api/admin/popup-sellers/{userId}/report")
    public PopupDtos.SellerReport sellerReport(@PathVariable UUID userId) {
        return service.report(userId);
    }

    @PostMapping("/api/popup/stalls/{id}/report")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void report(@PathVariable UUID id, @Valid @RequestBody ReportRequest req) {
        service.report(id, CurrentUser.id(), req);
    }

    // Admin.

    @GetMapping("/api/admin/popups")
    public PageResponse<AdminPopup> adminList(@RequestParam(required = false) AdminFilter filter,
                                              @RequestParam(required = false) UUID sellerId,
                                              @RequestParam(defaultValue = "0") int page) {
        return service.adminList(filter, sellerId, page);
    }

    @PostMapping("/api/admin/popups/{id}/remove")
    public AdminPopup remove(@PathVariable UUID id, @Valid @RequestBody(required = false) ReasonRequest req) {
        return service.remove(id, req == null ? null : req.reason());
    }

    @PostMapping("/api/admin/popups/{id}/restore")
    public AdminPopup restore(@PathVariable UUID id) {
        return service.restore(id);
    }

    @PostMapping("/api/admin/popup-sellers/{userId}/block")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void block(@PathVariable UUID userId, @Valid @RequestBody(required = false) ReasonRequest req) {
        service.block(userId, req == null ? null : req.reason());
    }

    @GetMapping("/api/admin/popup-settings")
    public SettingsDto settings() {
        return service.settingsView();
    }

    @PutMapping("/api/admin/popup-settings")
    public SettingsDto updateSettings(@Valid @RequestBody SettingsDto req) {
        return service.updateSettings(req);
    }

    @GetMapping("/api/admin/popup-sellers/{userId}/limits")
    public SellerLimits limits(@PathVariable UUID userId) {
        return service.limits(userId);
    }

    @PutMapping("/api/admin/popup-sellers/{userId}/limits")
    public SellerLimits setLimits(@PathVariable UUID userId, @Valid @RequestBody LimitsRequest req) {
        return service.setLimits(userId, req);
    }

    @PostMapping("/api/admin/popup-sellers/{userId}/unblock")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@PathVariable UUID userId) {
        service.unblock(userId);
    }
}
