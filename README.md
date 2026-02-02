# EasyTrip Database Design Document

## 1. Introduction
This document serves as distinct and rigorous documentation for the EasyTrip platform's database schema. It details the structural choices, entity relationships, and performance optimizations designed to support a scalable travel accommodation booking system.

The project structure relies on two main SQL files that define the system's foundation:
*   **`schema.sql`**: Contains the Data Definition Language (DDL) commands to build the database structure. This includes the creation of tables, enumerations, indexes, views, and automated triggers that maintain data integrity and consistency.
*   **`queries.sql`**: A collection of common Data Manipulation (DML) and Data Query (DQL) commands. This file documents the standard operations performed by the system.

![EasyTrip MER](images/EasyTripMER.jpg)

## 2. Purpose
The EasyTrip database is designed to act as the persistent storage layer for a travel booking application. Its primary purpose is to:
*   Manage user identities and host profiles securely.
*   Store detailed information about accommodations, including dynamic availability and pricing.
*   Process and track booking lifecycles from request to completion.
*   Facilitate social travel planning through group functionalities and voting mechanisms.
*   Aggregate reputation metrics (ratings) efficiently for fast read operations.

## 3. Scope
The schema covers the following functional domains:
*   **Identity Management**: Users and Hosts authentication data and profile details.
*   **Catalog Management**: Accommodations, addresses, and media assets.
*   **Commerce**: Booking transactions, status tracking, and availability scheduling.
*   **Reputation**: Review system affecting both specific units and host profiles.
*   **Social**: Group creation, membership management, and collaborative decision-making (voting on accommodations).

## 4. Entities and Schema Description

### 4.1. Core Identity
*   **users**: Stores fundamental access credentials (email, password hash) and personal identification (CPF, name).
*   **hosts**: An extension of the user entity. Contains profile information specific to property owners (bio) and materialized rating metrics.

### 4.2. Accommodation Catalog
*   **address**: Modular storage for location data, separating geography from the property entity to allow for efficient flexible querying (e.g., by State/City).
*   **accommodations**: The central entity representing a property. It links to a Host and an Address and stores base pricing and configuration (check-in/out times).
*   **accommodation_images**: Stores references to media assets associated with an accommodation, supporting ordering for display purposes.
*   **accommodation_availabilities**: Manages calendar dates for properties, including status (Available/Reserved) and dynamic price modifiers.

### 4.3. Operations & Commerce
*   **bookings**: Records the transactional state between a User and an Accommodation. It tracks dates (scheduled vs. actual), total price, and the current status (Pending, Confirmed, Cancelled, etc.).
*   **reviews**: Captures user feedback linked to a specific completed booking.
*   **user_favorites**: a simple join table tracking individual user wishlists.

### 4.4. Social Planning
*   **groups**: Containers for collaborative trip planning.
*   **group_members**: Manages the many-to-many relationship between users and groups, including roles (Administrator, Responsible, Member).
*   **group_favorites**: Accommodations selected by a group for potential booking.
*   **group_votes**: Tracks individual votes by members on the group's favorite accommodations to facilitate democratic decision-making.

## 5. Relationships
The database utilizes restricted relational integrity constraints:
*   **One-to-One**: `users` to `hosts`, `bookings` to `reviews`, `accommodations` to `address`.
*   **One-to-Many**: `hosts` to `accommodations`, `accommodations` to `bookings`, `accommodations` to `images`.
*   **Many-to-Many**: `users` to `groups` (via `group_members`), `groups` to `accommodations` (via `group_favorites`).

## 6. Optimizations
To ensure high performance for read-heavy operations (e.g., search and listing pages), the following strategies are implemented:
*   **Materialized Views via Triggers**: Ratings are not calculated on the fly during read operations. The `trg_reviews_update_ratings` trigger automatically updates `rating_count` and `average_rating` on both the `accommodations` and `hosts` tables whenever a new review is inserted. This O(1) read cost trade-off significantly improves catalog browsing performance.
*   **Indexing strategy**:
    *   `idx_accommodations_price`: Optimizes range queries on price.
    *   `idx_address_search`: Compound index on State and City for location-based filtering.
    *   `idx_accommodations_images_id`: Optimizes fetching images for a specific listing.
*   **Enum Types**: Use of PostgreSQL ENUMs (`uf`, `availability_status`, `booking_status`, `group_role`) ensures data integrity and storage efficiency for categorical data.