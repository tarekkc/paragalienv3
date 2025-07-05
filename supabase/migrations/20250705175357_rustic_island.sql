/*
  # Add approved_by foreign key relationship

  1. Changes
    - Add approved_by column to commandes table if it doesn't exist
    - Create foreign key relationship between commandes.approved_by and profiles.id
    - Update RLS policies to handle the new relationship

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control for approved_by field
*/

-- Add approved_by column to commandes table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'commandes' AND column_name = 'approved_by'
  ) THEN
    ALTER TABLE commandes ADD COLUMN approved_by uuid;
  END IF;
END $$;

-- Create foreign key relationship between commandes.approved_by and profiles.id
DO $$
BEGIN
  -- Check if foreign key constraint already exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'commandes_approved_by_fkey'
  ) THEN
    ALTER TABLE commandes 
    ADD CONSTRAINT commandes_approved_by_fkey 
    FOREIGN KEY (approved_by) REFERENCES profiles(id);
  END IF;
END $$;

-- Create index on approved_by for better query performance
CREATE INDEX IF NOT EXISTS idx_commandes_approved_by ON commandes(approved_by);

-- Update existing RLS policies to handle approved_by field
-- Allow admins to update approved_by field
DROP POLICY IF EXISTS "Admins can update orders" ON commandes;
CREATE POLICY "Admins can update orders"
  ON commandes
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

-- Allow users and admins to read orders with approved_by information
DROP POLICY IF EXISTS "Users can read own orders and admins can read all" ON commandes;
CREATE POLICY "Users can read own orders and admins can read all"
  ON commandes
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR 
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );