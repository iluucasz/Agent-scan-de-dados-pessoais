-- migration_005_create_areas_processos.sql
CREATE TABLE areas (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  organization_id INTEGER NOT NULL,
  created_by TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  UNIQUE(name, organization_id)
);

CREATE TABLE processos (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  purpose TEXT,
  area_id INTEGER NOT NULL,
  organization_id INTEGER NOT NULL,
  created_by TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (area_id) REFERENCES areas(id) ON DELETE CASCADE,
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  UNIQUE(name, area_id)
);

CREATE INDEX idx_areas_organization ON areas(organization_id);
CREATE INDEX idx_areas_active ON areas(is_active);
CREATE INDEX idx_processos_area ON processos(area_id);
CREATE INDEX idx_processos_organization ON processos(organization_id);
CREATE INDEX idx_processos_active ON processos(is_active);
