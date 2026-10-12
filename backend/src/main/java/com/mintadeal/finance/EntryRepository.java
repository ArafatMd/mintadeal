package com.mintadeal.finance;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface EntryRepository extends JpaRepository<LedgerEntry, UUID> {

    @Query("select coalesce(sum(e.amountMinor), 0) from LedgerEntry e where e.account = :account")
    long balance(Account account);

    @Query("""
            select coalesce(sum(e.amountMinor), 0) from LedgerEntry e
            where e.account = com.mintadeal.finance.Account.VENDOR_PAYABLE and e.vendorId = :vendorId""")
    long vendorBalance(UUID vendorId);

    @Query("""
            select e.vendorId, coalesce(sum(e.amountMinor), 0) from LedgerEntry e
            where e.account = com.mintadeal.finance.Account.VENDOR_PAYABLE group by e.vendorId""")
    List<Object[]> vendorBalances();

    @Query("""
            select new com.mintadeal.finance.VendorLine(j.id, j.journalType, j.description,
                   -e.amountMinor, j.createdAt)
            from LedgerEntry e, LedgerJournal j
            where e.journalId = j.id and e.account = com.mintadeal.finance.Account.VENDOR_PAYABLE
              and e.vendorId = :vendorId
            order by j.createdAt desc""")
    Page<VendorLine> statement(UUID vendorId, Pageable pageable);

    @Query("select coalesce(sum(e.amountMinor), 0) from LedgerEntry e")
    long total();
}
