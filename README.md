<p align="center">
  <img src="https://probr.io/banner.png" alt="Probr" width="600">
</p>

<h1 align="center">Probr — Server-Side Listener</h1>

<p align="center">
  Real-time monitoring for your Google Tag Manager Server-Side container.<br>
  Track tag health, execution times, user data quality, and e-commerce completeness — from any provider.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/GTM-Server--Side-4285F4?logo=googletagmanager&logoColor=white" alt="GTM Server-Side">
  <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License Apache 2.0">
  <img src="https://img.shields.io/badge/Version-1.0.0-green.svg" alt="Version 1.0.0">
  <img src="https://img.shields.io/badge/Provider-Any-orange.svg" alt="Any Provider">
</p>

---

## Overview

The **Probr Server-Side Listener** is a Google Tag Manager server-side tag template that monitors all events and tag executions flowing through your sGTM container. It sends structured monitoring data to your [Probr](https://probr.io) dashboard for real-time tracking quality analysis.

It works with **any sGTM hosting provider** — Stape, Addingwell, Google Cloud Platform, or self-hosted.

## What it monitors

| Signal                | Description                                                    |
|-----------------------|----------------------------------------------------------------|
| **Tag health**        | Success, failure, timeout, and exception rates per tag         |
| **Execution time**    | Per-tag execution duration in milliseconds                     |
| **Event volumes**     | Event counts by name (`page_view`, `purchase`, etc.)           |
| **User data quality** | Presence of email, phone, and address (enhanced conversions)   |
| **E-commerce quality**| Presence of `value`, `currency`, `transaction_id`, `items`     |

## Quick start

### 1. Get your credentials

Log in to the [Probr dashboard](https://probr.io), go to **Site Settings**, and copy your:
- **Ingest Endpoint** (e.g. `https://yoursite.probr.io/api/ingest`)
- **Ingest API Key**

### 2. Add the template

**From the Community Template Gallery (recommended):**

1. In your sGTM container, go to **Templates** > **Search Gallery**
2. Search for **Probr — Server-Side Listener**
3. Click **Add to workspace**

**Manual import:**

1. Download `template.tpl` from this repository
2. In your sGTM container, go to **Templates** > **New**
3. Click the three-dot menu > **Import**
4. Select the downloaded file

### 3. Configure the tag

Create a new tag using the Probr template and fill in the fields:

| Field                  | Required | Description                                      |
|------------------------|----------|--------------------------------------------------|
| **Probr Ingest Endpoint** | Yes   | Your HTTPS ingest URL                            |
| **Probr Ingest Key**      | Yes   | API key from Probr dashboard                     |
| **Track user data quality** | No  | Check presence of email, phone, address (default: on) |
| **Tag IDs to Exclude**    | No    | Comma-separated tag IDs to skip (avoid feedback loop) |
| **Send Mode**              | No    | `Per event` (default) or `Batched`               |
| **Batch Size**             | No    | Events per batch (default: 50, batched mode only) |

### 4. Set the trigger

Add an **All Events** trigger (or a custom trigger for specific events).

### 5. Add tag metadata

To avoid monitoring the Probr tag itself (feedback loop), note the Probr tag's ID and add it to the **Tag IDs to Exclude** field.

### 6. Publish

Preview your container to verify data appears in the Probr dashboard, then publish.

## Send modes

| Mode        | Behavior                              | Trade-off                                 |
|-------------|---------------------------------------|-------------------------------------------|
| **Per event** | One HTTP request per sGTM event      | Most reliable, real-time data             |
| **Batched**   | Buffers N events, sends in one POST  | Lower network overhead, slight data loss risk on instance restart |

> **Note:** Batched mode uses `templateDataStorage`, which is scoped to a single container instance. If the instance restarts before a batch is flushed, buffered events are lost. Use per-event mode if data completeness is critical.

## Tag exclusion

To prevent a feedback loop (the Probr tag monitoring itself), add the Probr tag's numeric ID to the **Tag IDs to Exclude** field. You can find the tag ID in the GTM UI or in Preview mode.

## Data flow

```
Browser / App
      │
      ▼
┌─────────────┐
│   sGTM       │
│  Container   │
└──────┬──────┘
       │  addEventCallback
       ▼
┌──────────────┐
│ Probr        │
│ Listener Tag │
└──────┬───────┘
       │  POST /api/ingest
       ▼
┌──────────────┐
│ Probr        │
│ Backend      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Probr        │
│ Dashboard    │
└──────────────┘
```

## Payload reference

### Per-event mode

```json
{
  "container_id": "GTM-XXXXXX",
  "event_name": "purchase",
  "timestamp_ms": 1700000000000,
  "tags": [
    {
      "id": "42",
      "name": "GA4",
      "status": "success",
      "execution_time": 120
    },
    {
      "id": "58",
      "name": "Meta CAPI",
      "status": "failure",
      "execution_time": 5003
    }
  ],
  "user_data": {
    "has_email": true,
    "has_phone": false,
    "has_first_name": true,
    "has_last_name": true,
    "has_city": false,
    "has_country": true
  },
  "ecommerce": {
    "has_value": true,
    "has_currency": true,
    "has_transaction_id": true,
    "has_items": true
  }
}
```

### Batched mode

```json
{
  "container_id": "GTM-XXXXXX",
  "batch": true,
  "window_start_ms": 1700000000000,
  "window_end_ms": 1700000060000,
  "total_events": 50,
  "event_counts": {
    "page_view": 30,
    "purchase": 8,
    "add_to_cart": 12
  },
  "tag_metrics": {
    "GA4": {
      "success": 48,
      "failure": 2,
      "timeout": 0,
      "exception": 0,
      "total_exec_ms": 4800,
      "count": 50
    }
  },
  "user_data_quality": {
    "email": 40,
    "phone": 12,
    "address": 8,
    "total": 50
  },
  "ecommerce_quality": {
    "value": 8,
    "currency": 8,
    "transaction_id": 7,
    "items": 8,
    "total": 8
  }
}
```

## Permissions

This tag requires the following sGTM sandbox permissions:

| Permission                | Reason                                              |
|---------------------------|-----------------------------------------------------|
| `send_http`               | Send monitoring data to the Probr API               |
| `read_event_data`         | Read event name, user data, and e-commerce fields   |
| `access_template_storage` | Buffer events in batched mode                       |
| `read_container_data`     | Read container ID for payload identification        |
| `logging`                 | Log debug messages to the sGTM console              |

## Compatibility

| Provider     | Status         | Notes                                  |
|--------------|----------------|----------------------------------------|
| **Stape**    | Fully tested   | —                                      |
| **Addingwell** | Fully tested | —                                      |
| **GCP (manual)** | Compatible | Standard sGTM on Cloud Run / App Engine |
| **AWS / Azure**  | Compatible | Any environment running sGTM           |

---

<p align="center">
  Built by <a href="https://digitalix.fr">DigitaliX</a> · <a href="https://probr.io">probr.io</a>
</p>
