package com.mintadeal.delivery;

import org.springframework.stereotype.Component;

import com.mintadeal.delivery.DeliveryDtos.JobView;
import com.mintadeal.delivery.DeliveryDtos.Stop;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;

@Component
class JobViews {

    private final UserRepository users;

    JobViews(UserRepository users) {
        this.users = users;
    }

    /** For riders: full contact details only on their own jobs, never the drop code. */
    JobView forAgent(DeliveryJob j, java.util.UUID agentId) {
        boolean mine = agentId.equals(j.getAgentId());
        return view(j, mine, mine, false);
    }

    JobView forAdmin(DeliveryJob j) {
        return view(j, true, true, true);
    }

    private JobView view(DeliveryJob j, boolean mine, boolean details, boolean admin) {
        User agent = j.getAgentId() == null ? null : users.findById(j.getAgentId()).orElse(null);
        Stop pickup = new Stop(j.getPickupName(), details ? j.getPickupPhone() : null, j.getPickupAddress(),
                j.getPickupArea(), j.getPickupLatitude(), j.getPickupLongitude());
        Stop drop = new Stop(details ? j.getDropName() : null, details ? j.getDropPhone() : null,
                details ? j.getDropAddress() : null, j.getDropArea(),
                details ? j.getDropLatitude() : round(j.getDropLatitude()),
                details ? j.getDropLongitude() : round(j.getDropLongitude()));
        return new JobView(j.getId(), j.getOrderCode(), j.getStatus(), j.getDistanceKm(), j.getItemCount(),
                j.getCashToCollectMinor(), pickup, drop, mine,
                agent == null ? null : agent.getName(), admin && agent != null ? agent.getPhone() : null,
                admin ? j.getCostMinor() : null, j.getFailureReason(), j.getRequestedAt(), j.getAssignedAt(),
                j.getPickedUpAt(), j.getDeliveredAt());
    }

    /** About 1 km precision: enough to judge the trip, not enough to find the house. */
    private static double round(double coordinate) {
        return Math.round(coordinate * 100) / 100.0;
    }
}
