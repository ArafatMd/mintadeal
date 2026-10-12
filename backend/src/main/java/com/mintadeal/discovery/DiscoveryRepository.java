package com.mintadeal.discovery;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.mintadeal.catalogue.Listing;

interface DiscoveryRepository extends JpaRepository<Listing, UUID> {

    /** Active listings of approved shops within a bounding box, plus every city-wide delivery shop. */
    @Query("""
            select new com.mintadeal.discovery.Candidate(l, v) from Listing l, Vendor v
            where l.vendorId = v.id
              and l.status = com.mintadeal.catalogue.ListingStatus.ACTIVE
              and v.status = com.mintadeal.vendor.VendorStatus.APPROVED
              and ((v.latitude between :minLat and :maxLat and v.longitude between :minLng and :maxLng)
                   or v.citywideDelivery = true)
            """)
    List<Candidate> nearbyCandidates(double minLat, double maxLat, double minLng, double maxLng);

    /** Active listings of approved shops that are either venue offers or from city-wide delivery shops. */
    @Query("""
            select new com.mintadeal.discovery.Candidate(l, v) from Listing l, Vendor v
            where l.vendorId = v.id
              and l.status = com.mintadeal.catalogue.ListingStatus.ACTIVE
              and v.status = com.mintadeal.vendor.VendorStatus.APPROVED
              and (l.listingType = com.mintadeal.catalogue.ListingType.OFFER or v.citywideDelivery = true)
            """)
    List<Candidate> citywideCandidates();

    @Query("""
            select new com.mintadeal.discovery.Candidate(l, v) from Listing l, Vendor v
            where l.vendorId = v.id and l.id = :listingId
            """)
    List<Candidate> byListingId(UUID listingId);
}
