"""add books

Revision ID: 82cfb6c58967
Revises: 8138dd4a77bd
Create Date: 2024-11-15 00:22:06.601549

"""
from alembic import op
import sqlalchemy as sa
import sqlmodel.sql.sqltypes


# revision identifiers, used by Alembic.
revision = '82cfb6c58967'
down_revision = '8138dd4a77bd'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('book',
    sa.Column('people_quantity', sa.Integer(), nullable=False),
    sa.Column('reserved_for', sa.DateTime(), nullable=False),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('restaurant_id', sa.Uuid(), nullable=False),
    sa.Column('owner_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['owner_id'], ['user.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['restaurant_id'], ['restaurant.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.add_column('item', sa.Column('rating', sa.Float(), nullable=False))
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('item', 'rating')
    op.drop_table('book')
    # ### end Alembic commands ###
