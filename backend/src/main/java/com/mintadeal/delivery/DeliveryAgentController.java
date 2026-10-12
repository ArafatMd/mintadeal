package com.mintadeal.delivery;

import java.util.EnumSet;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.Geo;
import com.mintadeal.delivery.DeliveryDtos.DropCode;
import com.mintadeal.delivery.DeliveryDtos.JobView;
import com.mintadeal.delivery.DeliveryDtos.Reason;

/** The delivery app. Only users with the DELIVERY_AGENT role reach these endpoints. */
@RestController
@RequestMapping("/api/delivery/jobs")
public class DeliveryAgentController {

    private final DeliveryService service;
    private final DeliveryJobRepository jobs;
    private final JobViews views;

    public DeliveryAgentController(DeliveryService service, DeliveryJobRepository jobs, JobViews views) {
        this.service = service;
        this.jobs = jobs;
        this.views = views;
    }

    /** Jobs waiting for a rider, nearest pickup first when the rider shares a location. */
    @GetMapping("/available")
    @Transactional(readOnly = true)
    public List<JobView> available(@RequestParam(required = false) Double lat,
                                   @RequestParam(required = false) Double lng) {
        UUID me = CurrentUser.id();
        var open = jobs.findByStatusOrderByRequestedAt(JobStatus.REQUESTED).stream();
        if (lat != null && lng != null) {
            open = open.sorted(java.util.Comparator.comparingDouble(
                    j -> Geo.distanceKm(lat, lng, j.getPickupLatitude(), j.getPickupLongitude())));
        }
        return open.map(j -> views.forAgent(j, me)).toList();
    }

    /** @param scope ACTIVE for jobs in hand, HISTORY for finished ones */
    @GetMapping
    @Transactional(readOnly = true)
    public List<JobView> mine(@RequestParam(defaultValue = "ACTIVE") String scope) {
        UUID me = CurrentUser.id();
        var statuses = "HISTORY".equals(scope)
                ? EnumSet.of(JobStatus.DELIVERED, JobStatus.FAILED, JobStatus.CANCELLED)
                : EnumSet.of(JobStatus.ASSIGNED, JobStatus.PICKED_UP);
        return jobs.findByAgentIdAndStatusInOrderByRequestedAtDesc(me, statuses, PageRequest.of(0, 50))
                .map(j -> views.forAgent(j, me)).getContent();
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public JobView one(@PathVariable UUID id) {
        UUID me = CurrentUser.id();
        DeliveryJob job = jobs.findById(id)
                .filter(j -> j.getStatus() == JobStatus.REQUESTED || me.equals(j.getAgentId()))
                .orElseThrow(() -> ApiException.notFound("Delivery job"));
        return views.forAgent(job, me);
    }

    @PostMapping("/{id}/claim")
    public JobView claim(@PathVariable UUID id) {
        UUID me = CurrentUser.id();
        return views.forAgent(service.claim(me, id), me);
    }

    @PostMapping("/{id}/release")
    public JobView release(@PathVariable UUID id) {
        UUID me = CurrentUser.id();
        return views.forAgent(service.release(me, id), me);
    }

    @PostMapping("/{id}/picked-up")
    public JobView pickedUp(@PathVariable UUID id) {
        UUID me = CurrentUser.id();
        return views.forAgent(service.pickedUp(me, id), me);
    }

    @PostMapping("/{id}/delivered")
    public JobView delivered(@PathVariable UUID id, @Valid @RequestBody DropCode req) {
        UUID me = CurrentUser.id();
        return views.forAgent(service.delivered(me, id, req.code()), me);
    }

    @PostMapping("/{id}/failed")
    public JobView failed(@PathVariable UUID id, @Valid @RequestBody Reason req) {
        UUID me = CurrentUser.id();
        return views.forAgent(service.failed(me, id, req.reason()), me);
    }
}
