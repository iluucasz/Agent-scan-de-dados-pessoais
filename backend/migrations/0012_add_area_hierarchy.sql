-- ============================================
-- Migration 0012: Hierarquia de Áreas
-- Adiciona suporte para áreas mãe e filhas
-- ============================================

-- Passo 1: Adicionar novas colunas à tabela areas
ALTER TABLE areas 
  ADD COLUMN parent_id INTEGER REFERENCES areas(id) ON DELETE SET NULL,
  ADD COLUMN level INTEGER DEFAULT 0 NOT NULL;

-- Passo 2: Atualizar áreas existentes (todas viram raiz)
UPDATE areas 
SET parent_id = NULL, 
    level = 0
WHERE parent_id IS NULL;

-- Passo 3: Criar tabela de hierarquia (closure table)
CREATE TABLE area_hierarchy (
  ancestor_id INTEGER NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
  descendant_id INTEGER NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
  depth INTEGER NOT NULL DEFAULT 0,
  
  PRIMARY KEY (ancestor_id, descendant_id),
  CHECK (depth >= 0)
);

-- Passo 4: Popular área_hierarchy com áreas existentes (self-reference)
INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
SELECT id, id, 0 
FROM areas 
WHERE is_active = true;

-- Passo 5: Criar índices para performance
CREATE INDEX idx_areas_parent ON areas(parent_id);
CREATE INDEX idx_areas_organization_parent ON areas(organization_id, parent_id);
CREATE INDEX idx_areas_level ON areas(level);
CREATE INDEX idx_hierarchy_ancestor ON area_hierarchy(ancestor_id);
CREATE INDEX idx_hierarchy_descendant ON area_hierarchy(descendant_id);
CREATE INDEX idx_hierarchy_depth ON area_hierarchy(depth);

-- Passo 6: Atualizar constraint UNIQUE
ALTER TABLE areas DROP CONSTRAINT IF EXISTS areas_name_organization_id_key;
ALTER TABLE areas ADD CONSTRAINT areas_name_org_parent_unique 
  UNIQUE(name, organization_id, COALESCE(parent_id, -1));

-- Passo 7: Função para manter hierarquia automaticamente
CREATE OR REPLACE FUNCTION maintain_area_hierarchy()
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
      
      -- 3. Atualizar nível baseado no pai
      NEW.level := (SELECT level + 1 FROM areas WHERE id = NEW.parent_id);
    ELSE
      -- Área raiz
      NEW.level := 0;
    END IF;
    
  ELSIF TG_OP = 'UPDATE' THEN
    -- Se mudou o parent_id, recalcular hierarquia
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      -- 1. Coletar todos os descendentes ANTES da mudança
      CREATE TEMP TABLE IF NOT EXISTS temp_descendants AS
      SELECT descendant_id
      FROM area_hierarchy
      WHERE ancestor_id = NEW.id AND depth > 0;
      
      -- 2. Remover relações antigas da área sendo movida (exceto self-reference)
      DELETE FROM area_hierarchy 
      WHERE descendant_id = NEW.id 
        AND ancestor_id != NEW.id;
      
      -- 3. Remover relações antigas de TODOS os descendentes (exceto self e entre descendentes)
      DELETE FROM area_hierarchy
      WHERE descendant_id IN (SELECT descendant_id FROM temp_descendants)
        AND ancestor_id NOT IN (
          SELECT descendant_id FROM temp_descendants
          UNION ALL
          SELECT NEW.id
        );
      
      -- 4. Adicionar novas relações para a área sendo movida
      IF NEW.parent_id IS NOT NULL THEN
        INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
        SELECT h.ancestor_id, NEW.id, h.depth + 1
        FROM area_hierarchy h
        WHERE h.descendant_id = NEW.parent_id;
        
        -- 5. Atualizar nível
        NEW.level := (SELECT level + 1 FROM areas WHERE id = NEW.parent_id);
      ELSE
        -- Virou raiz
        NEW.level := 0;
      END IF;
      
      -- 6. Reconstruir hierarquia de todos os descendentes
      INSERT INTO area_hierarchy (ancestor_id, descendant_id, depth)
      SELECT h.ancestor_id, d.descendant_id, h.depth + d.depth
      FROM area_hierarchy h
      CROSS JOIN (
        SELECT descendant_id, depth
        FROM area_hierarchy
        WHERE ancestor_id = NEW.id AND depth > 0
      ) d
      WHERE h.descendant_id = NEW.id;
      
      -- 7. Atualizar nível de todos os descendentes (recursivo)
      WITH RECURSIVE descendants AS (
        SELECT id, level
        FROM areas
        WHERE parent_id = NEW.id
        
        UNION ALL
        
        SELECT a.id, d.level + 1
        FROM areas a
        INNER JOIN descendants d ON a.parent_id = d.id
      )
      UPDATE areas a
      SET level = d.level + NEW.level + 1
      FROM descendants d
      WHERE a.id = d.id;
      
      -- 8. Limpar tabela temporária
      DROP TABLE IF EXISTS temp_descendants;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Passo 8: Criar trigger
DROP TRIGGER IF EXISTS trg_maintain_area_hierarchy ON areas;
CREATE TRIGGER trg_maintain_area_hierarchy
  BEFORE INSERT OR UPDATE ON areas
  FOR EACH ROW
  EXECUTE FUNCTION maintain_area_hierarchy();

-- Passo 9: Comentários
COMMENT ON TABLE area_hierarchy IS 'Closure table para hierarquia de áreas - permite queries rápidas de ancestrais e descendentes';
COMMENT ON COLUMN areas.parent_id IS 'Referência para área mãe. NULL = área raiz (nível 0)';
COMMENT ON COLUMN areas.level IS 'Nível na hierarquia. 0 = raiz, 1 = filha, 2 = neta, etc';
COMMENT ON COLUMN area_hierarchy.ancestor_id IS 'Área ancestral (pode ser a própria área quando depth=0)';
COMMENT ON COLUMN area_hierarchy.descendant_id IS 'Área descendente';
COMMENT ON COLUMN area_hierarchy.depth IS 'Distância entre ancestor e descendant. 0 = mesma área, 1 = filha direta, 2 = neta...';
