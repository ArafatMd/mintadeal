package com.mintadeal.order;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CheckoutRepository extends JpaRepository<Checkout, UUID> {

    Optional<Checkout> findByCustomerIdAndClientRequestId(UUID customerId, String clientRequestId);

    Optional<Checkout> findByPaymentReference(String paymentReference);

    boolean existsByCode(String code);

    List<Checkout> findByPaymentStatusAndPaymentDeadlineBefore(PaymentStatus status, Instant deadline);
}
