package com.mintadeal.files;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import com.mintadeal.common.ApiException;

class ImageDetectionTest {

    @Test
    void detectsImagesByContentNotName() {
        assertThat(FileController.detectImage(new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0})).isEqualTo("jpg");
        assertThat(FileController.detectImage(new byte[] {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'}))
                .isEqualTo("png");
        assertThatThrownBy(() -> FileController.detectImage("<html>".getBytes()))
                .isInstanceOf(ApiException.class);
    }
}
