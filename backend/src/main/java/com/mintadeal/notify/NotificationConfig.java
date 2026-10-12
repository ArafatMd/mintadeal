package com.mintadeal.notify;

import java.util.concurrent.Executor;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.SyncTaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
class NotificationConfig {

    /** Background senders normally; synchronous in tests so results can be checked straight away. */
    @Bean
    Executor notificationExecutor(@Value("${mintadeal.notifications.synchronous}") boolean synchronous) {
        if (synchronous) {
            return new SyncTaskExecutor();
        }
        ThreadPoolTaskExecutor pool = new ThreadPoolTaskExecutor();
        pool.setCorePoolSize(2);
        pool.setMaxPoolSize(4);
        pool.setQueueCapacity(1000);
        pool.setThreadNamePrefix("notify-");
        pool.initialize();
        return pool;
    }
}
