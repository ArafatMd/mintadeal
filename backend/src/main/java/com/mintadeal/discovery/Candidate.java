package com.mintadeal.discovery;

import com.mintadeal.catalogue.Listing;
import com.mintadeal.vendor.Vendor;

public record Candidate(Listing listing, Vendor vendor) {
}
