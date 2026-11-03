package com.mintadeal.account;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;

@RestController
public class AccountController {

    private final AccountService service;

    public AccountController(AccountService service) {
        this.service = service;
    }

    /** Deletes the signed-in person's account, or for a shop owner asks Mintadeal to. */
    @DeleteMapping("/api/me")
    public AccountService.Result delete() {
        return service.delete(CurrentUser.id());
    }
}
