package com.mintadeal.order;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ShopOrderRepository extends JpaRepository<ShopOrder, UUID> {

    List<ShopOrder> findByCheckoutIdOrderByCode(UUID checkoutId);

    Page<ShopOrder> findByCustomerIdOrderByCreatedAtDesc(UUID customerId, Pageable pageable);

    Page<ShopOrder> findByVendorIdAndStatusInOrderByCreatedAtDesc(UUID vendorId, Collection<OrderStatus> statuses,
                                                                Pageable pageable);

    long countByVendorIdAndStatus(UUID vendorId, OrderStatus status);

    /** Orders the shop has seen: unpaid online orders never reach the shop. */
    @Query("""
            select o from ShopOrder o
            where o.vendorId = :vendorId and o.status in :statuses
              and (o.acceptDeadline is not null or o.acceptedAt is not null)
            order by o.createdAt desc
            """)
    Page<ShopOrder> forVendor(UUID vendorId, Collection<OrderStatus> statuses, Pageable pageable);

    long countByVendorIdAndStatusIn(UUID vendorId, Collection<OrderStatus> statuses);

    List<ShopOrder> findByStatusAndAcceptDeadlineBefore(OrderStatus status, Instant deadline);

    /** @param q search text, or an empty string for no search (a null would reach PostgreSQL untyped) */
    @Query("""
            select o from ShopOrder o, Checkout c
            where o.checkoutId = c.id
              and (:status is null or o.status = :status)
              and (:q = '' or lower(o.code) like lower(concat('%', :q, '%'))
                   or c.contactPhone like concat('%', :q, '%')
                   or lower(o.vendorName) like lower(concat('%', :q, '%')))
            order by o.createdAt desc
            """)
    Page<ShopOrder> search(OrderStatus status, String q, Pageable pageable);
}
