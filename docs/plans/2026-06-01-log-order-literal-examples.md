# Literal Log Order Visualization Examples

## Context

These examples show concrete renderings that could be generated from one origin badge after logs are parsed by logical call-site depth. They are intentionally literal: each one should be readable as a product mock, documentation artifact, or debug export.

The sample interaction is the Clean Architecture network-error path:

```text
origin: tap-FF7
source: Trigger Network Error
result: recovered error state
duration: 362ms
```

## Example 1: Causal Graph

This view treats logs as a cause-and-effect graph. It is useful when async side effects, cache publications, or callbacks make a pure stack view feel too linear.

```mermaid
flowchart TD
    A["tap-FF7\nTrigger Network Error\nCleanArchDemoView:33"]
    B["OrderViewModel\ntriggerNetworkError()"]
    C["FetchOrdersUseCase\nexecuteWithError()"]
    D["OrderRepository\nfetchOrdersForcingError()"]
    E["OrderDataSource\nfetchOrdersForcingError()"]
    F["networkUnavailable\n313.7ms"]
    G["OrderCache\npublish revision 2"]
    H["UI listener\nApplied to UI"]
    I["Audit listener\nAudited"]
    J["Cache ack\nui + audit complete"]
    K["ViewModel recovers\npresent error state"]

    A --> B --> C --> D --> E
    E --> F
    F --> D
    D --> G
    G --> H
    G --> I
    H --> J
    I --> J
    D --> C --> B --> K

    classDef source fill:#eef6ff,stroke:#2b6cb0,color:#123;
    classDef call fill:#f7fafc,stroke:#718096,color:#111;
    classDef error fill:#fff5f5,stroke:#c53030,color:#111;
    classDef sideEffect fill:#f0fff4,stroke:#2f855a,color:#111;

    class A source;
    class B,C,D,E call;
    class F error;
    class G,H,I,J sideEffect;
    class K source;
```

Possible viewer behavior:

```text
[tap-FF7] Trigger Network Error
  5 calls
  1 failure
  1 handled error
  4 cache side effects
  final state: recovered
```

Why this is new:

- It does not require architectural lanes.
- It can show both stack flow and side-effect fan-out in one shape.
- It gives cache work a visible branch instead of burying it under indentation.

## Example 2: Error Spotlight Card

This view centers the first failing event, then shows the exact parent chain above it and recovery path below it. It is for debugging failures without reading the whole interaction.

```text
┌─ Error Spotlight ───────────────────────────────────────────┐
│ origin       tap-FF7                                        │
│ source       Trigger Network Error                          │
│ failed at    OrderDataSource.fetchOrdersForcingError()       │
│ error        networkUnavailable [OrderError]                 │
│ elapsed      313.7ms                                        │
├─ Call Path ─────────────────────────────────────────────────┤
│ 1  CleanArchDemoView.button("Trigger Network Error")         │
│ 2  OrderViewModel.triggerNetworkError()                      │
│ 3  FetchOrdersUseCase.executeWithError()                     │
│ 4  OrderRepository.fetchOrdersForcingError()                 │
│ 5  OrderDataSource.fetchOrdersForcingError()                 │
├─ Recovery ──────────────────────────────────────────────────┤
│ ✓ Repository caught networkUnavailable                       │
│ ✓ Cache published forcedError revision 2                     │
│ ✓ UI listener applied empty order state                      │
│ ✓ Audit listener recorded revision 2                         │
│ ✓ ViewModel recovered and presented error state              │
└──────────────────────────────────────────────────────────────┘
```

Compact copy/export form:

```text
tap-FF7 failed at depth 5 after 313.7ms:
UI > ViewModel > UseCase > Repository > DataSource
Recovered by Repository; UI updated from cache revision 2.
```

Why this is new:

- It optimizes for the failure-review workflow rather than full trace review.
- It separates the call path from recovery side effects.
- It can be generated even when only one error row is selected.

## Example 3: Actor Handoff Strip

This view emphasizes where execution moves between main actor and background work. It is useful for concurrency-heavy flows where logical depth is correct but actor hops are hard to see.

```text
tap-FF7  Trigger Network Error

main  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      UI tap
        └─ ViewModel.triggerNetworkError()
             └─ UseCase.executeWithError()
                  └─ Repository.fetchOrdersForcingError()
                       └─ DataSource.fetchOrdersForcingError()
                            ✕ networkUnavailable
                       └─ noteCacheUpdate(ui)
             └─ recovered error state

bg    ────────────────────────────────━━━━━━━━━━━━━━──────────────
                                      Cache.publish(revision: 2)
                                        ├─ yielded to audit
                                        ├─ yielded to ui
                                        ├─ ack audit
                                        ├─ ack ui
                                        └─ complete
```

Token-style variant for narrow terminals:

```text
[main] tap -> VM -> UC -> Repo -> DS ✕ networkUnavailable
[bg]                         Repo -> Cache publish r2 -> yield -> ack -> complete
[main]                                         UI listener -> recovered state
```

Why this is new:

- It makes actor hops the primary visual dimension.
- It can show background delivery without pretending it is a normal synchronous return.
- It gives async side effects a timeline position while preserving the origin badge.

## Example 4: Depth Receipt

This is a receipt-style summary for one interaction. It is meant to be copied into bug reports or test notes.

```text
╔══════════════════════════════════════════════════════════════╗
║ AutoLog Receipt                                             ║
╠══════════════════════════════════════════════════════════════╣
║ Origin:   tap-FF7                                           ║
║ Source:   button("Trigger Network Error")                   ║
║ Result:   recovered with handled networkUnavailable         ║
║ Runtime:  362ms                                             ║
╠══════════════════════════════════════════════════════════════╣
║ Depth  Component              Event                         ║
║ 1      CleanArchDemoView       tap Trigger Network Error     ║
║ 2      OrderViewModel          start triggerNetworkError     ║
║ 3      FetchOrdersUseCase      start executeWithError        ║
║ 4      OrderRepository         start fetchOrdersForcingError ║
║ 5      OrderDataSource         fail networkUnavailable       ║
║ 4      OrderRepository         publish cache revision 2      ║
║ 5      OrderViewModel          apply UI cache update         ║
║ 5      OrderViewModel          audit cache update            ║
║ 6      OrderCache              ack listeners complete        ║
║ 2      OrderViewModel          recover and update UI         ║
╚══════════════════════════════════════════════════════════════╝
```

Why this is new:

- It is friendly to text-only environments.
- It makes depth a first-class column instead of a visual indentation guess.
- It is concise enough for PR comments, test logs, and issue reports.

## Example 5: Storyboard Frames

This view turns a single origin badge into a short set of frames. It is useful for demo screens, docs, and teaching because each frame answers one question.

```text
Frame 1: User Intent
┌────────────────────────────────────────┐
│ User tapped "Trigger Network Error"    │
│ origin tap-FF7                         │
└────────────────────────────────────────┘

Frame 2: Call Chain
┌────────────────────────────────────────┐
│ ViewModel                              │
│   UseCase                              │
│     Repository                         │
│       DataSource                       │
└────────────────────────────────────────┘

Frame 3: Failure
┌────────────────────────────────────────┐
│ DataSource returned networkUnavailable │
│ after 313.7ms                          │
└────────────────────────────────────────┘

Frame 4: Recovery Side Effects
┌────────────────────────────────────────┐
│ Repository published forcedError r2    │
│ UI listener applied empty state        │
│ Audit listener recorded the update     │
└────────────────────────────────────────┘

Frame 5: Final State
┌────────────────────────────────────────┐
│ ViewModel recovered                    │
│ UI shows the handled error state       │
└────────────────────────────────────────┘
```

Why this is new:

- It favors explanation over forensic detail.
- It can be animated in the example app without changing the underlying log model.
- It gives product demos a visual narrative instead of raw log lines.

## Strongest Candidates

Build order recommendation:

1. Error Spotlight Card: fastest path to immediate debugging value.
2. Causal Graph: best visual explanation of side effects and cache callbacks.
3. Actor Handoff Strip: best way to understand concurrent work.
4. Depth Receipt: useful export format for GitHub issues and test failures.
5. Storyboard Frames: best demo/documentation format.
