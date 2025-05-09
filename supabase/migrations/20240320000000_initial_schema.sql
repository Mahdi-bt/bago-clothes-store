-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create enum types
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'delivered', 'completed', 'cancelled');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'unisex');

-- Create categories table
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create products table
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description_en TEXT,
    description_fr TEXT,
    description_ar TEXT,
    original_price DECIMAL(10,2) NOT NULL,
    selling_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(5,2),
    gender gender_type,
    material TEXT,
    brand TEXT,
    images TEXT[] DEFAULT '{}',
    category_id UUID REFERENCES categories(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create product_variants table
CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    size TEXT NOT NULL,
    color TEXT NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    sku TEXT UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create orders table
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    customer_alt_phone TEXT,
    customer_address TEXT NOT NULL,
    customer_governorate TEXT NOT NULL,
    customer_delegation TEXT NOT NULL,
    customer_zip_code TEXT,
    total_amount DECIMAL(10,2) NOT NULL,
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    status order_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create order_items table
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    product_variant_id UUID REFERENCES product_variants(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    price_at_time DECIMAL(10,2) NOT NULL,
    discount DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create storage bucket for product images
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_variants_updated_at
    BEFORE UPDATE ON product_variants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function to calculate product stock
CREATE OR REPLACE FUNCTION calculate_product_stock(product_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COALESCE(SUM(stock), 0)
        FROM product_variants
        WHERE product_id = $1 AND is_active = true
    );
END;
$$ LANGUAGE plpgsql;

-- Create RLS policies
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Categories policies
CREATE POLICY "Categories are viewable by everyone"
    ON categories FOR SELECT
    USING (true);

CREATE POLICY "Categories are insertable by authenticated users only"
    ON categories FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Categories are updatable by authenticated users only"
    ON categories FOR UPDATE
    TO authenticated
    USING (true);

-- Products policies
CREATE POLICY "Products are viewable by everyone"
    ON products FOR SELECT
    USING (true);

CREATE POLICY "Products are insertable by authenticated users only"
    ON products FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Products are updatable by authenticated users only"
    ON products FOR UPDATE
    TO authenticated
    USING (true);

-- Product variants policies
CREATE POLICY "Product variants are viewable by everyone"
    ON product_variants FOR SELECT
    USING (true);

CREATE POLICY "Product variants are insertable by authenticated users only"
    ON product_variants FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Product variants are updatable by authenticated users only"
    ON product_variants FOR UPDATE
    TO authenticated
    USING (true);

-- Orders policies
CREATE POLICY "Orders are viewable by authenticated users only"
    ON orders FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Orders are insertable by authenticated users only"
    ON orders FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Orders are updatable by authenticated users only"
    ON orders FOR UPDATE
    TO authenticated
    USING (true);

-- Order items policies
CREATE POLICY "Order items are viewable by authenticated users only"
    ON order_items FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Order items are insertable by authenticated users only"
    ON order_items FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Storage policies for product images
CREATE POLICY "Product images are viewable by everyone"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'product-images');

CREATE POLICY "Product images are insertable by authenticated users only"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "Product images are updatable by authenticated users only"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'product-images');

-- Create delivery_settings table
CREATE TABLE delivery_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    governorate TEXT NOT NULL,
    delegation TEXT NOT NULL,
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    min_order_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(governorate, delegation)
);

-- Enable RLS for delivery_settings
ALTER TABLE delivery_settings ENABLE ROW LEVEL SECURITY;

-- Delivery settings policies
CREATE POLICY "Delivery settings are viewable by everyone"
    ON delivery_settings FOR SELECT
    USING (true);

CREATE POLICY "Delivery settings are insertable by authenticated users only"
    ON delivery_settings FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Delivery settings are updatable by authenticated users only"
    ON delivery_settings FOR UPDATE
    TO authenticated
    USING (true);

-- Add trigger for delivery_settings updated_at
CREATE TRIGGER update_delivery_settings_updated_at
    BEFORE UPDATE ON delivery_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_product_variants_product ON product_variants(product_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_variant ON order_items(product_variant_id); 