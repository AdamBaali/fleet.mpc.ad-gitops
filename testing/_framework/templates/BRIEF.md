# Brief: <title>

Issue: <issue number> (parent: <number or none>) · Customer: <GitHub label> · Fleet version to test: <customer's version> · Written: <date>

## Background
<What led here, without names: the parent issue, earlier tickets, what the customer tried, any deadline.
Full story with names: private/CONTEXT.md.>

## The ask
<Two or three sentences in plain words: what the customer or team wants to know.>

## What needs testing
1. <question to answer> → tests <IDs>

## Lab needed
| Item | Have it? | Notes |
|---|---|---|
| Fleet | yes / needs `fleets/<name>.yml` (PR you merge) | |
| Hosts | <Windows VM, Linux container, Mac, phone> | |
| Other | <IdP, accounts, licenses> | |

## Plan
| ID | Test | Pass when | Runs by | Est. time |
|---|---|---|---|---|
| T-1 | <name> | <observable rule, the check> | agent now / overnight queue / you (phone, hardware) | |

## Not covered
- <item, and why>

## Questions for you
- <anything only you can answer, or "none">

## After approval
Agents run the "agent now" tests in parallel, the queue runs the VM steps, and you do the "you" steps from a checklist.
About <n> Claude sessions on Sonnet.
