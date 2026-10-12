package com.mintadeal.delivery;

import java.util.EnumSet;
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

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.PageResponse;
import com.mintadeal.delivery.DeliveryDtos.AssignRequest;
import com.mintadeal.delivery.DeliveryDtos.ChargeDto;
import com.mintadeal.delivery.DeliveryDtos.ChargesView;
import com.mintadeal.delivery.DeliveryDtos.JobView;
import com.mintadeal.delivery.DeliveryDtos.Reason;

@RestController
@RequestMapping("/api/admin/delivery")
public class AdminDeliveryController {

    private final DeliveryService service;
    private final DeliveryJobRepository jobs;
    private final VendorChargeRepository charges;
    private final JobViews views;
    private final DeliveryProperties props;
    private final com.mintadeal.finance.LedgerService ledger;
    private final AuditService audit;

    public AdminDeliveryController(DeliveryService service, DeliveryJobRepository jobs, VendorChargeRepository charges,
                                   JobViews views, DeliveryProperties props, AuditService audit,
            com.mintadeal.finance.LedgerService ledger) {
        this.service = service;
        this.jobs = jobs;
        this.charges = charges;
        this.views = views;
        this.props = props;
        this.ledger = ledger;
        this.audit = audit;
    }

    /** @param status a single status, or ACTIVE (default) for every job still on the road */
    @GetMapping("/jobs")
    @Transactional(readOnly = true)
    public PageResponse<JobView> list(@RequestParam(defaultValue = "ACTIVE") String status,
                                      @RequestParam(defaultValue = "0") int page) {
        var statuses = switch (status) {
            case "ACTIVE" -> EnumSet.of(JobStatus.REQUESTED, JobStatus.ASSIGNED, JobStatus.PICKED_UP);
            case "ALL" -> EnumSet.allOf(JobStatus.class);
            default -> EnumSet.of(JobStatus.valueOf(status));
        };
        return PageResponse.of(jobs.findByStatusInOrderByRequestedAtDesc(statuses, PageRequest.of(page, 50)),
                views::forAdmin);
    }

    @PostMapping("/jobs/{id}/assign")
    public JobView assign(@PathVariable UUID id, @Valid @RequestBody AssignRequest req) {
        JobView view = views.forAdmin(service.assign(id, req.phone()));
        audit.record("DELIVERY_ASSIGNED", "DELIVERY_JOB", id, req.phone());
        return view;
    }

    @PostMapping("/jobs/{id}/cancel")
    public JobView cancel(@PathVariable UUID id, @Valid @RequestBody Reason req) {
        JobView view = views.forAdmin(service.adminCancel(id, req.reason()));
        audit.record("DELIVERY_CANCELLED", "DELIVERY_JOB", id, req.reason());
        return view;
    }

    @GetMapping("/charges")
    @Transactional(readOnly = true)
    public ChargesView vendorCharges(@RequestParam UUID vendorId) {
        return new ChargesView(ledger.duesOf(vendorId), props.maxOutstandingMinor(),
                charges.findByVendorIdOrderByCreatedAtDesc(vendorId, PageRequest.of(0, 100)).map(ChargeDto::of).getContent());
    }
}
