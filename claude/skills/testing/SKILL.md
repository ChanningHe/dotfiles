---
name: testing
description: Testing strategy and standards. Apply when writing tests, designing test architecture, or evaluating test coverage.
---

# Testing Standards

## Core Philosophy

"Code without tests is broken code." Tests are not optional—they're part of the product.

## When to Write Tests

| Scenario | Requirement |
|----------|-------------|
| **Core business logic** | Mandatory 100% coverage |
| **Public APIs** | Must have integration + edge case tests |
| **Bug fixes** | Regression test required before closing |
| **Utility functions** | Unit test if function > 5 lines |
| **UI components** | Snapshot test + interaction test |

## Test Quality Standards

1. **No Flaky Tests**
   - Tests must be deterministic. Random failures = broken test, not environment issue
   - Mock external dependencies (network, DB, time)
   - Clean up state between tests

2. **One Assert Per Test**
   - Each test should verify ONE behavior
   - If you need 5 asserts, split into 5 tests

3. **Arrange-Act-Assert**
   ```javascript
   // Arrange: Setup test data
   const user = { name: "Alice", role: "admin" };

   // Act: Execute the function
   const result = canDelete(user);

   // Assert: Verify expected outcome
   expect(result).toBe(true);
   ```

## Test Hierarchy

```
Integration Tests  ← Slow, comprehensive
    ��
    ├─ E2E (End-to-End)
    └─ Service Layer Tests
Unit Tests         ← Fast, isolated
    │
    ├─ Function Tests
    └─ Component Tests
```

**Rule**: Write unit tests first, add integration tests only for critical paths.

## Anti-Patterns

❌ **Testing Implementation**
```javascript
// Bad: Tests internal structure
expect(component.state.value).toBe(10);
```

✅ **Testing Behavior**
```javascript
// Good: Tests public interface
expect(renderedComponent).toHaveTextContent("Count: 10");
```

❌ **Over-mocking**
```javascript
// Bad: Mocking too much breaks test value
jest.spyOn(Math, "random").mockReturnValue(0.5);
```

✅ **Test the Real Thing**
```javascript
// Good: Use deterministic test data
const result = processUser({ id: "test-123" });
```

## Coverage Goals

- **Core domain**: 90%+
- **Utilities**: 80%+
- **UI components**: 70%+
- **E2E**: Cover critical user journeys only
