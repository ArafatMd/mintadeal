package com.mintadeal.support;

import java.util.Collection;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.mintadeal.identity.Role;
import com.mintadeal.support.SupportTicket.Status;

public interface SupportTicketRepository extends JpaRepository<SupportTicket, UUID> {

    Page<SupportTicket> findByOpenedByAndOpenerRoleOrderByLastMessageAtDesc(UUID openedBy, Role role, Pageable page);

    Page<SupportTicket> findByStatusInOrderByLastMessageAtAsc(Collection<Status> statuses, Pageable page);

    Page<SupportTicket> findAllByOrderByLastMessageAtDesc(Pageable page);

    long countByOpenedByAndOpenerRoleAndStatusNot(UUID openedBy, Role role, Status status);

    long countByStatus(Status status);

    boolean existsByCode(String code);
}
