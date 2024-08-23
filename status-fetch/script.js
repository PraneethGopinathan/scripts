document.addEventListener("DOMContentLoaded", function() {
    const countdownElement = document.getElementById("countdown");

    function getNextTenthMinuteTime() {
        const now = new Date();
        const currentMinutes = now.getMinutes();
        const remainingMinutes = 10 - (currentMinutes % 10);
        now.setMinutes(currentMinutes + remainingMinutes);
        now.setSeconds(0);
        now.setMilliseconds(0);
        return now.getTime();
    }

    function startCountdown() {
        const endTime = getNextTenthMinuteTime();
        localStorage.setItem("countdownEndTime", endTime);
        updateCountdown(endTime);
    }

    function updateCountdown(endTime) {
        const interval = setInterval(() => {
            const now = Date.now();
            const remainingTime = endTime - now;

            if (remainingTime <= 0) {
                clearInterval(interval);
                // Refresh the browser
                location.reload();
            } else {
                const minutes = Math.floor((remainingTime % (1000 * 60 * 60)) / (1000 * 60));
                const seconds = Math.floor((remainingTime % (1000 * 60)) / 1000);
                countdownElement.textContent = `${minutes}m ${seconds}s`;

                // Reload page every 20 seconds for the first minute
                if (minutes === 9 && seconds <= 20) {
                    location.reload();
                }
            }
        }, 1000);
    }

    const savedEndTime = localStorage.getItem("countdownEndTime");

    if (savedEndTime) {
        const endTime = parseInt(savedEndTime, 10);
        const remainingTime = endTime - Date.now();
        if (remainingTime > 0) {
            updateCountdown(endTime);
        } else {
            localStorage.removeItem("countdownEndTime");
            startCountdown();
        }
    } else {
        startCountdown();
    }
});
