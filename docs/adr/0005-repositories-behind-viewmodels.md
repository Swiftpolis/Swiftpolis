# No @Query in Views: SwiftData sits behind repositories

Each View owns its ViewModel, and ViewModels reach SwiftData only through repositories, even though `@Query` in Views is the usual SwiftUI approach. Queue and schedule rules are the highest-risk part of the port, and this lets them run in tests with no UI or real store. Live progress stays in memory, and only status changes and periodic progress are saved, because Persepolis updates its display five times a second.
