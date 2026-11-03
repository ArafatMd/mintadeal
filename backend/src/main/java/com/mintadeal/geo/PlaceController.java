package com.mintadeal.geo;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PlaceController {

    private final PlaceNames places;

    public PlaceController(PlaceNames places) {
        this.places = places;
    }

    /** The neighbourhood and pincode at a point; 204 when not known, and the app uses the nearest listed area. */
    @GetMapping("/api/discovery/place")
    public ResponseEntity<PlaceNames.Place> place(@RequestParam double lat, @RequestParam double lng) {
        return places.at(lat, lng).map(ResponseEntity::ok).orElse(ResponseEntity.noContent().build());
    }
}
