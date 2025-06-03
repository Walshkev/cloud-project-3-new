const { DataTypes } = require('sequelize');
const sequelize = require('../lib/sequelize');
const bcrypt = require('bcrypt');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  email: {
    type: DataTypes.STRING,
    unique: true,
    allowNull: false,
    validate: { isEmail: true }
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false,
    set(value) {
      // Only hash if not already hashed (for bulkCreate with pre-hashed passwords)
      if (value && !value.startsWith('$2a$')) {
        const hash = bcrypt.hashSync(value, 8);
        this.setDataValue('password', hash);
      } else {
        this.setDataValue('password', value);
      }
    }
  },
  admin: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
});

// Always enforce admin is false on user creation
User.beforeValidate((user, options) => {
  if (user.isNewRecord) {
    user.admin = false;
  }
});

module.exports = { User };