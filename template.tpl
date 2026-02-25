___TERMS_OF_SERVICE___

By creating or modifying this file, you are agreeing to the Google Tag
Manager Community Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-platform/tag-manager/templates/gallery-tos
(or such other URL as Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "probr_listener",
  "version": 1,
  "securityGroups": [],
  "displayName": "Probr — Server-Side Listener",
  "brand": {
    "id": "probr",
    "displayName": "Probr"
  },
  "description": "Monitors all server-side events and tag executions, sending aggregated data to your Probr dashboard for real-time tracking quality analysis. Tracks tag success rates, execution times, user data quality (enhanced conversions), and e-commerce parameter completeness — independently of your hosting provider.",
  "containerContexts": [
    "SERVER"
  ],
  "categories": [
    "ANALYTICS",
    "UTILITY"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "probrEndpoint",
    "displayName": "Probr Ingest Endpoint",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": ["^https://.*"]
      }
    ],
    "help": "The HTTPS URL of your Probr API ingestion endpoint (e.g. https://probr.example.com/api/ingest)."
  },
  {
    "type": "TEXT",
    "name": "probrApiKey",
    "displayName": "Probr Ingest Key",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "The ingest API key for this site. Found in Probr dashboard under Site Settings."
  },
  {
    "type": "CHECKBOX",
    "name": "trackUserData",
    "checkboxText": "Track user data quality (email, phone, address presence)",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "When enabled, the tag checks for presence of enhanced conversion data (email, phone, address) and reports quality scores to the Probr dashboard."
  },
  {
    "type": "TEXT",
    "name": "excludeTagIds",
    "displayName": "Tag IDs to Exclude (comma-separated)",
    "simpleValueType": true,
    "defaultValue": "",
    "help": "Comma-separated list of tag IDs to exclude from monitoring. Leave empty to monitor all tags."
  },
  {
    "type": "SELECT",
    "name": "sendMode",
    "displayName": "Send Mode",
    "macrosInSelect": false,
    "selectItems": [
      { "value": "per_event", "displayValue": "Per event (recommended)" },
      { "value": "batched", "displayValue": "Batched (lower network overhead)" }
    ],
    "simpleValueType": true,
    "defaultValue": "per_event",
    "help": "Per event: sends one HTTP request per event (most reliable, real-time). Batched: buffers events in memory and sends periodically (lower overhead, slight data loss risk on container instance restart)."
  },
  {
    "type": "TEXT",
    "name": "batchSize",
    "displayName": "Batch Size (events)",
    "simpleValueType": true,
    "defaultValue": "50",
    "enablingConditions": [
      { "paramName": "sendMode", "paramValue": "batched", "type": "EQUALS" }
    ],
    "help": "Number of events to buffer before sending a batch to the Probr API."
  }
]


___SANDBOXED_JS_FOR_SERVER___

/**
 * Probr — Server-Side Listener Tag
 *
 * Captures all events and tag execution results flowing through the sGTM
 * container and sends monitoring data to the Probr API for real-time
 * tracking quality analysis.
 *
 * What it monitors:
 * - Tag execution results: success, failure, timeout, exception
 * - Tag execution time (ms)
 * - Event volumes by name
 * - User data quality: presence of email, phone, address fields
 * - E-commerce data quality: presence of value, currency, transaction_id, items
 *
 * Works with any sGTM hosting provider (Stape, Addingwell, self-hosted, etc.)
 *
 * @version 1.0.0
 * @license Apache-2.0
 */

const addEventCallback = require('addEventCallback');
const sendHttpRequest = require('sendHttpRequest');
const getEventData = require('getEventData');
const getContainerVersion = require('getContainerVersion');
const getTimestampMillis = require('getTimestampMillis');
const JSON = require('JSON');
const logToConsole = require('logToConsole');
const templateDataStorage = require('templateDataStorage');
const makeInteger = require('makeInteger');
const makeString = require('makeString');
const getType = require('getType');

// ── Configuration ─────────────────────────────────────────────

const ENDPOINT = data.probrEndpoint;
const API_KEY = data.probrApiKey;
const TRACK_USER_DATA = data.trackUserData !== false;
const SEND_MODE = data.sendMode || 'per_event';
const BATCH_SIZE = makeInteger(data.batchSize || '50');

// Parse excluded tag IDs into an array
const excludeTagIds = [];
if (data.excludeTagIds) {
  const parts = makeString(data.excludeTagIds).split(',');
  for (var i = 0; i < parts.length; i++) {
    var trimmed = parts[i].trim();
    if (trimmed) excludeTagIds.push(trimmed);
  }
}

// ── Event Data Collection ─────────────────────────────────────

const eventName = getEventData('event_name') || 'unknown';
const containerVersion = getContainerVersion();
const containerId = containerVersion.containerId || 'unknown';
const timestamp = getTimestampMillis();

// Check user data presence for quality scoring (enhanced conversions)
var userDataPresence = {};
if (TRACK_USER_DATA) {
  const userData = getEventData('user_data');
  const hasUserData = getType(userData) === 'object' && userData !== null;

  userDataPresence = {
    has_email: hasUserData && !!userData.email_address,
    has_phone: hasUserData && !!userData.phone_number,
    has_first_name: hasUserData && !!userData.address && !!userData.address.first_name,
    has_last_name: hasUserData && !!userData.address && !!userData.address.last_name,
    has_city: hasUserData && !!userData.address && !!userData.address.city,
    has_country: hasUserData && !!userData.address && !!userData.address.country
  };
}

// Collect e-commerce data quality signals on relevant events
var ecommercePresence = {};
if (eventName === 'purchase' || eventName === 'begin_checkout' ||
    eventName === 'add_to_cart' || eventName === 'add_payment_info') {
  ecommercePresence = {
    has_value: !!getEventData('value'),
    has_currency: !!getEventData('currency'),
    has_transaction_id: !!getEventData('transaction_id'),
    has_items: !!getEventData('items')
  };
}

// ── Tag Result Capture via addEventCallback ───────────────────

addEventCallback(function(ctId, eventData) {
  // Build tag results array from the event metadata
  var tags = [];
  if (eventData && eventData.tags) {
    for (var t = 0; t < eventData.tags.length; t++) {
      var tag = eventData.tags[t];
      var tagId = makeString(tag.id);

      // Skip excluded tags (e.g. the Probr tag itself)
      var skip = false;
      for (var e = 0; e < excludeTagIds.length; e++) {
        if (excludeTagIds[e] === tagId) {
          skip = true;
          break;
        }
      }
      if (skip) continue;

      tags.push({
        id: tagId,
        name: tag.name || '',
        status: tag.status,
        execution_time: tag.executionTime || 0
      });
    }
  }

  // ── Send Mode: Per Event ──────────────────────────────────

  if (SEND_MODE === 'per_event') {
    var payload = {
      container_id: containerId,
      event_name: eventName,
      timestamp_ms: timestamp,
      tags: tags,
      user_data: userDataPresence,
      ecommerce: ecommercePresence
    };

    sendHttpRequest(ENDPOINT, function(statusCode) {
      if (statusCode >= 200 && statusCode < 300) {
        logToConsole('Probr: event sent');
      } else {
        logToConsole('Probr: send failed (' + statusCode + ')');
      }
    }, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Probr-Key': API_KEY
      },
      timeout: 5000
    }, JSON.stringify(payload));

    return;
  }

  // ── Send Mode: Batched ────────────────────────────────────

  var buffer = templateDataStorage.getItemCopy('probr_buffer');
  if (!buffer || getType(buffer) !== 'object') {
    buffer = {
      events: {},
      tags: {},
      user_data: { email: 0, phone: 0, address: 0, total: 0 },
      ecommerce: { value: 0, currency: 0, transaction_id: 0, items: 0, total: 0 },
      count: 0,
      window_start: timestamp
    };
  }

  // Increment event counter
  buffer.count = (buffer.count || 0) + 1;
  buffer.events[eventName] = (buffer.events[eventName] || 0) + 1;

  // Aggregate tag metrics
  for (var ti = 0; ti < tags.length; ti++) {
    var tagName = tags[ti].name || ('tag_' + tags[ti].id);
    if (!buffer.tags[tagName]) {
      buffer.tags[tagName] = { success: 0, failure: 0, timeout: 0, exception: 0, total_exec_ms: 0, count: 0 };
    }
    var tm = buffer.tags[tagName];
    tm.count = (tm.count || 0) + 1;
    tm.total_exec_ms = (tm.total_exec_ms || 0) + (tags[ti].execution_time || 0);
    if (tags[ti].status === 'success') tm.success = (tm.success || 0) + 1;
    else if (tags[ti].status === 'failure') tm.failure = (tm.failure || 0) + 1;
    else if (tags[ti].status === 'timeout') tm.timeout = (tm.timeout || 0) + 1;
    else if (tags[ti].status === 'exception') tm.exception = (tm.exception || 0) + 1;
  }

  // Aggregate user data presence
  if (TRACK_USER_DATA) {
    buffer.user_data.total = (buffer.user_data.total || 0) + 1;
    if (userDataPresence.has_email) buffer.user_data.email = (buffer.user_data.email || 0) + 1;
    if (userDataPresence.has_phone) buffer.user_data.phone = (buffer.user_data.phone || 0) + 1;
    if (userDataPresence.has_first_name || userDataPresence.has_last_name)
      buffer.user_data.address = (buffer.user_data.address || 0) + 1;
  }

  // Aggregate ecommerce presence
  if (ecommercePresence.has_value !== undefined) {
    buffer.ecommerce.total = (buffer.ecommerce.total || 0) + 1;
    if (ecommercePresence.has_value) buffer.ecommerce.value = (buffer.ecommerce.value || 0) + 1;
    if (ecommercePresence.has_currency) buffer.ecommerce.currency = (buffer.ecommerce.currency || 0) + 1;
    if (ecommercePresence.has_transaction_id) buffer.ecommerce.transaction_id = (buffer.ecommerce.transaction_id || 0) + 1;
    if (ecommercePresence.has_items) buffer.ecommerce.items = (buffer.ecommerce.items || 0) + 1;
  }

  // Check flush condition: send when batch is full
  if (buffer.count >= BATCH_SIZE) {
    var batchPayload = {
      container_id: containerId,
      batch: true,
      window_start_ms: buffer.window_start,
      window_end_ms: timestamp,
      total_events: buffer.count,
      event_counts: buffer.events,
      tag_metrics: buffer.tags,
      user_data_quality: buffer.user_data,
      ecommerce_quality: buffer.ecommerce
    };

    sendHttpRequest(ENDPOINT, function(statusCode) {
      if (statusCode >= 200 && statusCode < 300) {
        logToConsole('Probr: batch sent (' + buffer.count + ' events)');
      } else {
        logToConsole('Probr: batch send failed (' + statusCode + ')');
      }
    }, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Probr-Key': API_KEY
      },
      timeout: 10000
    }, JSON.stringify(batchPayload));

    // Reset buffer after flush
    buffer = {
      events: {},
      tags: {},
      user_data: { email: 0, phone: 0, address: 0, total: 0 },
      ecommerce: { value: 0, currency: 0, transaction_id: 0, items: 0, total: 0 },
      count: 0,
      window_start: timestamp
    };
  }

  templateDataStorage.setItemCopy('probr_buffer', buffer);
});

// Signal tag success immediately — monitoring is non-blocking
data.gtmOnSuccess();


___SERVER_PERMISSIONS___

[
  {
    "instance": "send_http",
    "isRequired": true,
    "allowedUrls": "any"
  },
  {
    "instance": "read_event_data",
    "isRequired": true,
    "allowedKeys": "any"
  },
  {
    "instance": "access_template_storage",
    "isRequired": true
  },
  {
    "instance": "read_container_data",
    "isRequired": true
  },
  {
    "instance": "logging",
    "isRequired": true,
    "logLevel": "debug"
  }
]
