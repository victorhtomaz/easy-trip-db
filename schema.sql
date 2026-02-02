------------------------------------------------------
-- TABLES
------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  cpf CHAR(11) NOT NULL,
  email VARCHAR(160) NOT NULl,
  password_hash VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (cpf),
  UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS hosts (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  bio TEXT NOT NULL,
  rating_count INTEGER NOT NULL DEFAULT 0,
  average_rating DOUBLE PRECISION NOT NULL DEFAULT 0,
  image_url VARCHAR(1023),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  FOREIGN KEY (user_id) REFERENCES users (id),
  UNIQUE (user_id),
  CHECK (average_rating >= 0 AND average_rating <= 5)
);

CREATE TYPE uf AS ENUM (
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 
  'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 
  'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
); 

CREATE TABLE IF NOT EXISTS address (
  id SERIAL PRIMARY KEY,
  zip_code CHAR(8) NOT NULL,
  street VARCHAR(255) NOT NULL,
  number SMALLINT NOT NULL,
  complement VARCHAR(255) NULL,
  neighborhood VARCHAR (255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state UF NOT NULL
);

CREATE TABLE IF NOT EXISTS accommodations (
  id SERIAL PRIMARY KEY,
  host_id INTEGER NOT NULL,
  address_id INTEGER NOT NULL,
  title VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  rating_count INTEGER NOT NULL DEFAULT 0,
  average_rating DOUBLE PRECISION NOT NULL DEFAULT 0,
  check_in_time TIME NOT NULL,
  check_out_time TIME NOT NULL,
  base_price DECIMAL(8,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  FOREIGN KEY (host_id) REFERENCES hosts (id),
  FOREIGN KEY (address_id) REFERENCES address (id),
  UNIQUE (address_id),
  CHECK (average_rating >= 0 AND average_rating <= 5),
  CHECK (base_price > 0)
);

CREATE TABLE IF NOT EXISTS accommodation_images (
  id SERIAL PRIMARY KEY,
  accommodation_id INTEGER NOT NULL,
  url VARCHAR(1023) NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 1,

  FOREIGN KEY (accommodation_id) REFERENCES accommodations (id),
  CHECK (display_order > 0)
);

CREATE TYPE availability_status AS ENUM (
  'DISPONIVEL', 'RESERVADO'
);

CREATE TABLE IF NOT EXISTS accommodation_availabilities (
  id SERIAL PRIMARY KEY,
  accommodation_id INTEGER NOT NULL,
  date DATE NOT NULL,
  price_modifier DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  status AVAILABILITY_STATUS NOT NULL DEFAULT 'DISPONIVEL',

  FOREIGN KEY (accommodation_id) REFERENCES accommodations (id),
  UNIQUE (accommodation_id, date),
  CHECK (price_modifier > 0 AND price_modifier <= 3.00)
);

CREATE TABLE IF NOT EXISTS user_favorites (
  user_id INTEGER NOT NULL,
  accommodation_id INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (user_id, accommodation_id),
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (accommodation_id) REFERENCES accommodations (id)
);

CREATE TYPE booking_status AS ENUM (
  'PENDENTE', 'NEGADA', 'CONFIRMADA', 'CANCELADA', 'FINALIZADA'
);

CREATE TABLE IF NOT EXISTS bookings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  accommodation_id INTEGER NOT NULL,
  check_in TIMESTAMPTZ NOT NULL,
  check_out TIMESTAMPTZ NOT NULL,
  actual_check_in TIMESTAMPTZ NULL,
  actual_check_out TIMESTAMPTZ NULL,
  total_price DECIMAL(10,2) NOT NULL,
  status BOOKING_STATUS NOT NULL DEFAULT 'PENDENTE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (accommodation_id) REFERENCES accommodations (id),
  CHECK (total_price > 0),
  CHECK (actual_check_in >= check_in),
  CHECK (actual_check_out >= check_out) 
);

CREATE TABLE IF NOT EXISTS reviews (
  id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL,
  rating DOUBLE PRECISION NOT NULL DEFAULT 0,
  comment TEXT NULL,

  FOREIGN KEY (booking_id) REFERENCES bookings (id),
  UNIQUE (booking_id),
  CHECK (rating >= 0 AND rating <= 5)
);

CREATE TABLE IF NOT EXISTS groups (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT NULL
);

CREATE TYPE group_role AS ENUM (
  'ADMINISTRADOR', 'RESPONSAVEL', 'MEMBRO'
);

CREATE TABLE IF NOT EXISTS group_members (
  user_id INTEGER NOT NULL,
  group_id INTEGER NOT NULL,
  role GROUP_ROLE NOT NULL DEFAULT 'MEMBRO',

  PRIMARY KEY (user_id, group_id),
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (group_id) REFERENCES groups (id)
);

CREATE TABLE IF NOT EXISTS group_favorites (
  group_id INTEGER NOT NULL,
  accommodation_id INTEGER NOT NULL,

  PRIMARY KEY (group_id, accommodation_id),
  FOREIGN KEY (group_id) REFERENCES groups (id),
  FOREIGN KEY (accommodation_id) REFERENCES accommodations (id)
);

CREATE TABLE IF NOT EXISTS group_votes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  group_id INTEGER NOT NULL,
  accommodation_id INTEGER NOT NULL,

  FOREIGN KEY (user_id, group_id) REFERENCES group_members (user_id, group_id) ON DELETE CASCADE,
  FOREIGN KEY (group_id, accommodation_id) REFERENCES group_favorites (group_id, accommodation_id) ON DELETE CASCADE,
  UNIQUE (user_id, group_id, accommodation_id)
);

------------------------------------------------------
-- INDEX
------------------------------------------------------

CREATE INDEX idx_accommodations_price ON accommodations (base_price);

CREATE INDEX idx_address_search ON address (state, city);

CREATE INDEX idx_accommodations_images_id ON accommodation_images (accommodation_id, display_order);

CREATE INDEX idx_host_accommodations ON accommodations (host_id);

------------------------------------------------------
-- FUNCTIONS
------------------------------------------------------

CREATE OR REPLACE FUNCTION update_accommodation_and_host_ratings ()
  RETURNS TRIGGER AS
$$
  DECLARE
    v_accommodation_id INTEGER;
    v_host_id INTEGER;
    v_average_rating_host DOUBLE PRECISION;
    v_rating_count_host INTEGER;
    v_average_rating_accommodation DOUBLE PRECISION;
    v_rating_count_accommodation INTEGER;
  BEGIN

    SELECT accommodation_id INTO v_accommodation_id
    FROM bookings
    WHERE id = NEW.booking_id;

    SELECT host_id INTO v_host_id
    FROM accommodations
    WHERE id = v_accommodation_id;
  
    SELECT COUNT(*), COALESCE(AVG(rating), 0) INTO v_rating_count_accommodation, v_average_rating_accommodation
    FROM reviews
    JOIN bookings b ON booking_id = b.id
    WHERE accommodation_id = v_accommodation_id;

    UPDATE accommodations
    SET
      rating_count = v_rating_count_accommodation,
      average_rating = v_average_rating_accommodation
    WHERE id = v_accommodation_id;
  
    SELECT SUM(rating_count), AVG(average_rating) INTO v_rating_count_host, v_average_rating_host
    FROM accommodations
    WHERE host_id = v_host_id;

    UPDATE hosts
    SET
        rating_count = v_rating_count_host,
        average_rating = v_average_rating_host
    WHERE id = v_host_id;

    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

------------------------------------------------------
-- TRIGGERS
------------------------------------------------------

CREATE TRIGGER trg_reviews_update_ratings
  AFTER INSERT
  ON reviews
  FOR EACH ROW
EXECUTE FUNCTION update_accommodation_and_host_ratings();

------------------------------------------------------
-- VIEWS
------------------------------------------------------

CREATE OR REPLACE VIEW vw_accommodations_details AS 
  SELECT 
    a.id, 
    a.title, 
    a.description, 
    a.average_rating, 
    a.rating_count, 
    a.check_in_time, 
    a.check_out_time, 
    a.base_price,
    addr.zip_code, 
    addr.street, 
    addr.number, 
    addr.complement, 
    addr.neighborhood, 
    addr.city, 
    addr.state,
    img.url AS image_url
  FROM accommodations a
  JOIN address addr ON addr.id = a.address_id
  LEFT JOIN accommodation_images img ON img.accommodation_id = a.id AND img.display_order = 1;

CREATE OR REPLACE VIEW vw_bookings_history AS 
  SELECT
    b.id,
    b.user_id,
    b.accommodation_id,
    a.title AS accommodation_title,
    b.check_in,
    b.check_out,
    b.actual_check_in,
    b.actual_check_out,
    b.total_price,
    b.status,
    b.created_at,
    r.rating,
    r.comment AS review_comment
  FROM bookings b
  JOIN accommodations a ON a.id = b.accommodation_id
  LEFT JOIN reviews r ON r.booking_id = b.id;

CREATE OR REPLACE VIEW vw_reviews_with_author AS 
  SELECT
    r.id,
    r.booking_id,
    r.rating,
    r.comment,
    u.name AS user_name
  FROM reviews r
  JOIN bookings b ON r.booking_id = b.id
  JOIN users u ON b.user_id = u.id;