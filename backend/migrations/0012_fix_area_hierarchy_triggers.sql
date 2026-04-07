-- ============================================
-- Migration 0012 FIX: Corrigir Triggers de Hierarquia
-- Problema: Trigger BEFORE causava erro de foreign key
-- Solução: Separar em 2 triggers (BEFORE para level, AFTER para closure table)
-- ============================================

-- Passo 1: Dropar triggers e functions antigas
DROP TRIGGER IF EXISTS trg_maintain_area_hierarchy ON areas;
DROP FUNCTION IF EXISTS maintain_area_hierarchy();

-- Passo 2: Criar function para calcular level (BEFORE trigger)
CREATE OR REPLACE FUNCTION maintain_area_level()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Calcular e setar o level ANTES de inserir
    IF NEW.parent_id IS NOT NULL THEN
      SELECT level + 1 INTO NEW.level FROM areas WHERE id = NEW.parent_id;
    ELSE
      NEW.level := 0;
    END IF;
    
    RETURN NEW;
    
  ELSIF TG_OP = 'UPDATE' THEN
    -- Se mudou o parent_id, recalcular level
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      IF NEW.parent_id IS NOT NULL THEN
        SELECT level + 1 INTO NEW.level FROM areas WHERE id = NEW.parent_id;
      ELSE
        NEW.level := 0;
      END IF;
      
      -- Atualizar level de todos os descendentes (recursivo)
      WITH RECURSIVE descendants AS (
        SELECT id, NEW.level + 1 as new_level
        FROM areas
        WHERE parent_id = NEW.id
        
        UNION ALL
        
        SELECT a.id, d.new_level + 1
        FROM areas a
        INNER JOIN descendants d ON a.parent_id = d.id
      )
      UPDATE areas a
      SET level = d.new_level
      FROM descendants d
      WHERE a.id = d.id;
    END IF;
    
    RETURN NEW;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Passo 3: Criar trigger BEFORE para calcular level
CREATE TRIGGER trg_maintain_area_level
  BEFORE INSERT OR UPDATE ON areas
  FOR EACH ROW
  EXECUTE FUNCTION maintain_area_level();

-- Passo 4: Criar function para manter closure table (AFTER trigger)
CREATE OR REPLACE FUNCTION maintain_area_hierarchy_closure()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- 1. Inserir self-reference
    INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
    VALUES (NEW.id, NEW.id, 0);
    
    -- 2. Se tem pai, copiar toda a hierarquia do pai
    IF NEW.parent_id IS NOT NULL THEN
      INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
      SELECT h.ancestor_id, NEW.id, h.depth + 1
      FROM area_hierarchy h
      WHERE h.descendant_id = NEW.parent_id;
    END IF;
    
  ELSIF TG_OP = 'UPDATE' THEN
    -- Se mudou o parent_id, recalcular hierarquia
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      -- 1. Coletar descendentes
      CREATE TEMP TABLE IF NOT EXISTS temp_desc AS
      SELECT descendant_id FROM area_hierarchy WHERE ancestor_id = NEW.id AND depth > 0;
      
      -- 2. Remover relações antigas da área
      DELETE FROM area_hierarchy WHERE descendant_id = NEW.id AND ancestor_id != NEW.id;
      
      -- 3. Remover relações antigas dos descendentes
      DELETE FROM area_hierarchy
      WHERE descendant_id IN (SELECT descendant_id FROM temp_desc)
        AND ancestor_id NOT IN (SELECT descendant_id FROM temp_desc UNION ALL SELECT NEW.id);
      
      -- 4. Adicionar novas relações
      IF NEW.parent_id IS NOT NULL THEN
        INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
        SELECT h.ancestor_id, NEW.id, h.depth + 1
        FROM area_hierarchy h
        WHERE h.descendant_id = NEW.parent_id;
      END IF;
      
      -- 5. Reconstruir hierarquia dos descendentes
      INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
      SELECT h.ancestor_id, d.descendant_id, h.depth + d.depth
      FROM area_hierarchy h
      CROSS JOIN (
        SELECT descendant_id, depth FROM area_hierarchy WHERE ancestor_id = NEW.id AND depth > 0
      ) d
      WHERE h.descendant_id = NEW.id;
      
      DROP TABLE IF EXISTS temp_desc;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Passo 5: Criar trigger AFTER para closure table
CREATE TRIGGER trg_maintain_area_hierarchy_closure
  AFTER INSERT OR UPDATE ON areas
  FOR EACH ROW
  EXECUTE FUNCTION maintain_area_hierarchy_closure();

-- Passo 6: Comentários
COMMENT ON FUNCTION maintain_area_level() IS 'Calcula automaticamente o nível (level) de uma área baseado em seu parent_id';
COMMENT ON FUNCTION maintain_area_hierarchy_closure() IS 'Mantém a closure table area_hierarchy sincronizada quando áreas são criadas ou movidas';
