# CloudWatch Logs Insights - queries to keep handy

Open **CloudWatch -> Logs Insights**, pick a log group, paste a query.

## Latest errors
```
fields @timestamp, @message
| filter @message like /(?i)(error|exception|fail)/
| sort @timestamp desc
| limit 50
```

## Errors per 5 minutes (graph it)
```
filter @message like /ERROR/
| stats count(*) as errors by bin(5m)
```

## Lambda: slowest invocations and memory use
```
filter @type = "REPORT"
| fields @requestId, @duration, @billedDuration, @maxMemoryUsed / 1000000 as maxMemMB
| sort @duration desc
| limit 20
```

## Lambda: cold starts
```
filter @type = "REPORT" and ispresent(@initDuration)
| stats count(*) as coldStarts, avg(@initDuration) as avgInitMs by bin(1h)
```

## ALB access logs / JSON app logs: top 5xx paths
```
fields @timestamp, path, status
| filter status >= 500
| stats count(*) as hits by path
| sort hits desc
| limit 10
```

# CloudTrail - who did what?

```bash
# Who terminated instances in the last 24h?
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=TerminateInstances \
  --start-time "$(date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ)" \
  --query "Events[].{time:EventTime,user:Username,event:EventName}" --output table

# Everything a specific user did
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=alice --max-results 20

# Console logins (look for failures!)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin --max-results 20
```

`lookup-events` covers the last **90 days** of management events. For longer
retention or data events (S3 object reads, Lambda invokes), create a **trail**
that writes to an S3 bucket.
