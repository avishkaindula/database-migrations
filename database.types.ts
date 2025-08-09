export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      admin_memberships: {
        Row: {
          admin_id: string
          created_at: string
          id: number
          organization_id: string
          status: string | null
          updated_at: string
        }
        Insert: {
          admin_id: string
          created_at?: string
          id?: number
          organization_id: string
          status?: string | null
          updated_at?: string
        }
        Update: {
          admin_id?: string
          created_at?: string
          id?: number
          organization_id?: string
          status?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_memberships_admin_id_fkey"
            columns: ["admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      admins: {
        Row: {
          active_organization_id: string | null
          address: string | null
          avatar_url: string | null
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          phone: string | null
          updated_at: string
        }
        Insert: {
          active_organization_id?: string | null
          address?: string | null
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          phone?: string | null
          updated_at?: string
        }
        Update: {
          active_organization_id?: string | null
          address?: string | null
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          phone?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "admins_active_organization_id_fkey"
            columns: ["active_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      agents: {
        Row: {
          address: string | null
          avatar_url: string | null
          created_at: string
          email: string | null
          energy: number
          full_name: string | null
          id: string
          phone: string | null
          points: number
          updated_at: string
        }
        Insert: {
          address?: string | null
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          energy?: number
          full_name?: string | null
          id: string
          phone?: string | null
          points?: number
          updated_at?: string
        }
        Update: {
          address?: string | null
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          energy?: number
          full_name?: string | null
          id?: string
          phone?: string | null
          points?: number
          updated_at?: string
        }
        Relationships: []
      }
      energy_transactions: {
        Row: {
          agent_id: string
          balance_after: number
          created_at: string
          description: string
          energy_amount: number
          id: number
          metadata: Json | null
          mission_id: string | null
          reference_id: string | null
          reference_type: string | null
          submission_id: string | null
          transaction_type: string
        }
        Insert: {
          agent_id: string
          balance_after: number
          created_at?: string
          description: string
          energy_amount: number
          id?: number
          metadata?: Json | null
          mission_id?: string | null
          reference_id?: string | null
          reference_type?: string | null
          submission_id?: string | null
          transaction_type: string
        }
        Update: {
          agent_id?: string
          balance_after?: number
          created_at?: string
          description?: string
          energy_amount?: number
          id?: number
          metadata?: Json | null
          mission_id?: string | null
          reference_id?: string | null
          reference_type?: string | null
          submission_id?: string | null
          transaction_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "energy_transactions_agent_id_fkey"
            columns: ["agent_id"]
            isOneToOne: false
            referencedRelation: "agents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "energy_transactions_mission_id_fkey"
            columns: ["mission_id"]
            isOneToOne: false
            referencedRelation: "missions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "energy_transactions_submission_id_fkey"
            columns: ["submission_id"]
            isOneToOne: false
            referencedRelation: "mission_submissions"
            referencedColumns: ["id"]
          },
        ]
      }
      mission_bookmarks: {
        Row: {
          agent_id: string
          created_at: string
          id: number
          mission_id: string
        }
        Insert: {
          agent_id: string
          created_at?: string
          id?: number
          mission_id: string
        }
        Update: {
          agent_id?: string
          created_at?: string
          id?: number
          mission_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "mission_bookmarks_agent_id_fkey"
            columns: ["agent_id"]
            isOneToOne: false
            referencedRelation: "agents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mission_bookmarks_mission_id_fkey"
            columns: ["mission_id"]
            isOneToOne: false
            referencedRelation: "missions"
            referencedColumns: ["id"]
          },
        ]
      }
      mission_submissions: {
        Row: {
          additional_data: Json | null
          agent_id: string
          completed_at: string | null
          created_at: string
          guidance_evidence: Json
          id: string
          mission_id: string
          review_notes: string | null
          review_score: number | null
          reviewed_by: string | null
          status: string
          updated_at: string
        }
        Insert: {
          additional_data?: Json | null
          agent_id: string
          completed_at?: string | null
          created_at?: string
          guidance_evidence?: Json
          id?: string
          mission_id: string
          review_notes?: string | null
          review_score?: number | null
          reviewed_by?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          additional_data?: Json | null
          agent_id?: string
          completed_at?: string | null
          created_at?: string
          guidance_evidence?: Json
          id?: string
          mission_id?: string
          review_notes?: string | null
          review_score?: number | null
          reviewed_by?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "mission_submissions_agent_id_fkey"
            columns: ["agent_id"]
            isOneToOne: false
            referencedRelation: "agents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mission_submissions_mission_id_fkey"
            columns: ["mission_id"]
            isOneToOne: false
            referencedRelation: "missions"
            referencedColumns: ["id"]
          },
        ]
      }
      missions: {
        Row: {
          created_at: string
          created_by: string
          description: string
          energy_awarded: number
          guidance_steps: Json
          id: string
          instructions: Json
          is_featured: boolean
          organization_id: string
          points_awarded: number
          status: string
          thumbnail_url: string | null
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          description: string
          energy_awarded: number
          guidance_steps?: Json
          id?: string
          instructions?: Json
          is_featured?: boolean
          organization_id: string
          points_awarded: number
          status?: string
          thumbnail_url?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          description?: string
          energy_awarded?: number
          guidance_steps?: Json
          id?: string
          instructions?: Json
          is_featured?: boolean
          organization_id?: string
          points_awarded?: number
          status?: string
          thumbnail_url?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "missions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_permissions: {
        Row: {
          created_at: string
          id: number
          organization_id: string
          permission_type: Database["public"]["Enums"]["organization_permission_type"]
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          organization_id: string
          permission_type: Database["public"]["Enums"]["organization_permission_type"]
          requested_by: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          organization_id?: string
          permission_type?: Database["public"]["Enums"]["organization_permission_type"]
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_permissions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          address: string | null
          contact_email: string | null
          contact_phone: string | null
          created_at: string
          description: string | null
          id: string
          name: string
          updated_at: string
          website: string | null
        }
        Insert: {
          address?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          id?: string
          name: string
          updated_at?: string
          website?: string | null
        }
        Update: {
          address?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          updated_at?: string
          website?: string | null
        }
        Relationships: []
      }
      point_transactions: {
        Row: {
          agent_id: string
          balance_after: number
          created_at: string
          description: string
          id: number
          metadata: Json | null
          mission_id: string | null
          points_amount: number
          reference_id: string | null
          reference_type: string | null
          submission_id: string | null
          transaction_type: string
        }
        Insert: {
          agent_id: string
          balance_after: number
          created_at?: string
          description: string
          id?: number
          metadata?: Json | null
          mission_id?: string | null
          points_amount: number
          reference_id?: string | null
          reference_type?: string | null
          submission_id?: string | null
          transaction_type: string
        }
        Update: {
          agent_id?: string
          balance_after?: number
          created_at?: string
          description?: string
          id?: number
          metadata?: Json | null
          mission_id?: string | null
          points_amount?: number
          reference_id?: string | null
          reference_type?: string | null
          submission_id?: string | null
          transaction_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "point_transactions_agent_id_fkey"
            columns: ["agent_id"]
            isOneToOne: false
            referencedRelation: "agents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "point_transactions_mission_id_fkey"
            columns: ["mission_id"]
            isOneToOne: false
            referencedRelation: "missions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "point_transactions_submission_id_fkey"
            columns: ["submission_id"]
            isOneToOne: false
            referencedRelation: "mission_submissions"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          id: number
          permission: Database["public"]["Enums"]["app_permission"]
          role: Database["public"]["Enums"]["app_role"]
        }
        Insert: {
          id?: number
          permission: Database["public"]["Enums"]["app_permission"]
          role: Database["public"]["Enums"]["app_role"]
        }
        Update: {
          id?: number
          permission?: Database["public"]["Enums"]["app_permission"]
          role?: Database["public"]["Enums"]["app_role"]
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          id: number
          organization_id: string | null
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: number
          organization_id?: string | null
          role: Database["public"]["Enums"]["app_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: number
          organization_id?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      approve_organization_privileges: {
        Args: { target_organization_id: string; privilege_types?: string[] }
        Returns: Json
      }
      authorize: {
        Args: {
          organization_id?: string
          requested_permission: Database["public"]["Enums"]["app_permission"]
        }
        Returns: boolean
      }
      bookmark_or_start_mission: {
        Args: { p_agent_id: string; p_mission_id: string; p_action: string }
        Returns: string
      }
      complete_mission_submission: {
        Args: {
          p_submission_id: string
          p_reviewed_by?: string
          p_review_notes?: string
          p_review_score?: number
        }
        Returns: undefined
      }
      custom_access_token_hook: {
        Args: { event: Json }
        Returns: Json
      }
      get_active_org_privileges: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_pending_organization_approvals: {
        Args: Record<PropertyKey, never>
        Returns: {
          organization_id: string
          organization_name: string
          contact_email: string
          admin_name: string
          admin_email: string
          requested_privileges: Json
          created_at: string
        }[]
      }
      has_organization_role: {
        Args: {
          role_name: Database["public"]["Enums"]["app_role"]
          organization_id: string
        }
        Returns: boolean
      }
      is_organization_member: {
        Args: { organization_id: string }
        Returns: boolean
      }
      organization_has_privilege: {
        Args: {
          organization_id: string
          privilege: Database["public"]["Enums"]["organization_permission_type"]
        }
        Returns: boolean
      }
      reject_organization_privileges: {
        Args: {
          target_organization_id: string
          privilege_types?: string[]
          rejection_reason?: string
        }
        Returns: Json
      }
    }
    Enums: {
      app_permission:
        | "manage_organization"
        | "manage_agents"
        | "create_missions"
        | "manage_missions"
        | "create_rewards"
        | "manage_rewards"
        | "approve_organizations"
        | "manage_admins"
      app_role: "agent" | "admin"
      organization_permission_type:
        | "mobilizing_partners"
        | "mission_partners"
        | "reward_partners"
        | "cin_administrators"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DefaultSchema = Database[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof Database },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
  ? Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      app_permission: [
        "manage_organization",
        "manage_agents",
        "create_missions",
        "manage_missions",
        "create_rewards",
        "manage_rewards",
        "approve_organizations",
        "manage_admins",
      ],
      app_role: ["agent", "admin"],
      organization_permission_type: [
        "mobilizing_partners",
        "mission_partners",
        "reward_partners",
        "cin_administrators",
      ],
    },
  },
} as const

