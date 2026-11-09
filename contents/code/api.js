.pragma library

/**
 * Shared state across all Fear & Greed widget instances in the same plasmashell process.
 * Because of `.pragma library`, multiple instances on the user's panels share this
 * singleton module, deduplicating network requests per data source.
 *
 * Data Sources:
 *   0 = CNN Stock Market Fear & Greed Index (https://production.dataviz.cnn.io/index/fearandgreed/graphdata)
 *   1 = Alternative.me Crypto Fear & Greed Index (https://api.alternative.me/fng/?limit=1)
 */

// Active widget instances: Map of instanceId -> { dataSource: 0|1, callback: fn }
var registeredInstances = {};

// Shared cache per dataSource (0 or 1)
// Structure: { score: Number, rating: String, previousClose: Number|null, previousWeek: Number|null, previousMonth: Number|null, previousYear: Number|null, timestamp: String, sourceName: String }
var indexCache = {};

// Per-source fetch state: { 0: { isFetching, fetchStartedTimestamp, lastFetchTimestamp }, 1: { ... } }
var fetchState = {
    0: { isFetching: false, fetchStartedTimestamp: 0, lastFetchTimestamp: 0 },
    1: { isFetching: false, fetchStartedTimestamp: 0, lastFetchTimestamp: 0 }
};

var minFetchGapMs = 5000;
var requestTimeoutMs = 10000;

/**
 * Normalize rating string into Title Case ("Extreme Fear", "Fear", "Neutral", "Greed", "Extreme Greed")
 * or derive from score if rating is missing.
 */
function normalizeRating(score, rawRating) {
    if (rawRating && String(rawRating).trim().length > 0) {
        const words = String(rawRating).trim().toLowerCase().split(/\s+/);
        for (let i = 0; i < words.length; i++) {
            if (words[i].length > 0) {
                words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1);
            }
        }
        return words.join(" ");
    }
    const val = Number(score);
    if (val < 25) return "Extreme Fear";
    if (val < 45) return "Fear";
    if (val <= 55) return "Neutral";
    if (val <= 75) return "Greed";
    return "Extreme Greed";
}

/**
 * Register or update a widget instance's data source and listener callback.
 */
function registerInstance(instanceId, dataSource, callback) {
    const src = (Number(dataSource) === 1) ? 1 : 0;
    registeredInstances[instanceId] = {
        dataSource: src,
        callback: callback
    };
    deliverCachedToInstance(instanceId);
}

/**
 * Unregister a widget instance when destroyed.
 */
function unregisterInstance(instanceId) {
    delete registeredInstances[instanceId];
}

/**
 * Deliver cached index object to a specific instance.
 */
function deliverCachedToInstance(instanceId) {
    const entry = registeredInstances[instanceId];
    if (!entry || typeof entry.callback !== "function") return;

    const cached = indexCache[entry.dataSource];
    if (cached) {
        entry.callback({
            score: cached.score,
            rating: cached.rating,
            previousClose: cached.previousClose,
            previousWeek: cached.previousWeek,
            previousMonth: cached.previousMonth,
            previousYear: cached.previousYear,
            timestamp: cached.timestamp,
            sourceName: cached.sourceName,
            dataSource: entry.dataSource
        });
    }
}

/**
 * Broadcast updated cache to all registered widget instances for a given dataSource.
 */
function notifyInstancesForSource(dataSource) {
    for (const instanceId in registeredInstances) {
        if (registeredInstances[instanceId].dataSource === dataSource) {
            deliverCachedToInstance(instanceId);
        }
    }
}

/**
 * Determine which data sources are actively used across all registered widget instances.
 */
function getActiveDataSources() {
    const seen = {};
    const list = [];
    for (const instanceId in registeredInstances) {
        const src = registeredInstances[instanceId].dataSource;
        if (!seen[src]) {
            seen[src] = true;
            list.push(src);
        }
    }
    return list;
}

/**
 * Fetch CNN Stock Market Fear & Greed Index (dataSource = 0).
 */
function fetchCnnIndex(now, onComplete) {
    const url = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata?_t=" + now;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 8000;

    let handled = false;
    function finish() {
        if (handled) return;
        handled = true;
        onComplete();
    }

    xhr.ontimeout = function() {
        console.warn("FearAndGreed: CNN request timed out.");
        finish();
    };

    xhr.onerror = function() {
        console.warn("FearAndGreed: CNN network error.");
        finish();
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (handled) return;
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    if (data && data.fear_and_greed && data.fear_and_greed.score !== undefined) {
                        const fg = data.fear_and_greed;
                        const score = Math.max(0, Math.min(100, Number(fg.score)));
                        indexCache[0] = {
                            score: score,
                            rating: normalizeRating(score, fg.rating),
                            previousClose: fg.previous_close !== undefined ? Number(fg.previous_close) : null,
                            previousWeek: fg.previous_1_week !== undefined ? Number(fg.previous_1_week) : null,
                            previousMonth: fg.previous_1_month !== undefined ? Number(fg.previous_1_month) : null,
                            previousYear: fg.previous_1_year !== undefined ? Number(fg.previous_1_year) : null,
                            timestamp: fg.timestamp || "",
                            sourceName: "CNN Market Fear & Greed"
                        };
                    }
                } catch (e) {
                    console.error("FearAndGreed: CNN JSON parse error:", e);
                }
            } else {
                console.warn("FearAndGreed: CNN HTTP status", xhr.status);
            }
            finish();
        }
    };

    xhr.open("GET", url);
    xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0");
    xhr.setRequestHeader("Accept", "application/json, text/plain, */*");
    xhr.setRequestHeader("Referer", "https://www.cnn.com/markets/fear-and-greed");
    xhr.setRequestHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    xhr.setRequestHeader("Pragma", "no-cache");
    xhr.send();
}

/**
 * Fetch Alternative.me Crypto Fear & Greed Index (dataSource = 1).
 */
function fetchCryptoIndex(now, onComplete) {
    const url = "https://api.alternative.me/fng/?limit=2&_t=" + now;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 8000;

    let handled = false;
    function finish() {
        if (handled) return;
        handled = true;
        onComplete();
    }

    xhr.ontimeout = function() {
        console.warn("FearAndGreed: Alternative.me request timed out.");
        finish();
    };

    xhr.onerror = function() {
        console.warn("FearAndGreed: Alternative.me network error.");
        finish();
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (handled) return;
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    if (data && Array.isArray(data.data) && data.data.length > 0) {
                        const latest = data.data[0];
                        const prev = data.data.length > 1 ? data.data[1] : null;
                        const score = Math.max(0, Math.min(100, Number(latest.value)));
                        indexCache[1] = {
                            score: score,
                            rating: normalizeRating(score, latest.value_classification),
                            previousClose: prev && prev.value !== undefined ? Number(prev.value) : null,
                            previousWeek: null,
                            previousMonth: null,
                            previousYear: null,
                            timestamp: latest.timestamp ? new Date(Number(latest.timestamp) * 1000).toISOString() : "",
                            sourceName: "Crypto Fear & Greed (Alternative.me)"
                        };
                    }
                } catch (e) {
                    console.error("FearAndGreed: Alternative.me JSON parse error:", e);
                }
            } else {
                console.warn("FearAndGreed: Alternative.me HTTP status", xhr.status);
            }
            finish();
        }
    };

    xhr.open("GET", url);
    xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0");
    xhr.setRequestHeader("Accept", "application/json");
    xhr.setRequestHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    xhr.setRequestHeader("Pragma", "no-cache");
    xhr.send();
}

/**
 * Refresh a specific dataSource with deduplication and watchdog timeout protection.
 */
function refreshSource(src, force) {
    const state = fetchState[src];
    if (!state) return;

    const now = Date.now();

    if (state.isFetching) {
        if ((now - state.fetchStartedTimestamp) > requestTimeoutMs) {
            console.warn("FearAndGreed: Previous request timed out, resetting fetch lock for source", src);
            state.isFetching = false;
        } else {
            return;
        }
    }

    if (!force && (now - state.lastFetchTimestamp) < minFetchGapMs) {
        notifyInstancesForSource(src);
        return;
    }

    state.isFetching = true;
    state.fetchStartedTimestamp = now;
    state.lastFetchTimestamp = now;

    function onDone() {
        state.isFetching = false;
        notifyInstancesForSource(src);
    }

    if (src === 1) {
        fetchCryptoIndex(now, onDone);
    } else {
        fetchCnnIndex(now, onDone);
    }
}

/**
 * Refresh all active data sources across all registered widget instances.
 */
function refreshAllInstances(force) {
    const sources = getActiveDataSources();
    for (let i = 0; i < sources.length; i++) {
        refreshSource(sources[i], force);
    }
}
